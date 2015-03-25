class Token
  property kind

  def initialize
    @kind = :unknown
    @content_io = StringIO.new
  end

  def empty
    @content_io = StringIO.new
  end

  def append_char(c)
    @content_io << c
  end

  def content
    @content_io.to_s
  end

  def to_s
    content + "#" + kind.to_s
  end

  def inspect(io)
    io << to_s
  end
end

class Lexer
  getter tokens

  def initialize(@input)
    @index = 0
    @tokens = [] of Token
    @current_token = Token.new
  end

  def run
    until @index >= @input.size
      char = @input[@index]
      @index += 1

      case char
      when '('
        @current_token.kind = :lparen
        @current_token.empty
        finish_token
      when ')'
        @current_token.kind = :rparen
        @current_token.empty
        finish_token
      when ' ', '\t'
        @current_token.kind = :space
        @current_token.append_char(char)
        consume_space
        finish_token
      when '\n'
        @current_token.kind = :newline
        @current_token.empty
        finish_token
      when '"'
        @current_token.kind = :string
        @current_token.append_char(char)
        consume_until_end_of_string
        finish_token
      when '0' .. '9'
        @current_token.kind = :number
        unread_char # input required for decision making
        consume_number
        finish_token
      when 'a' .. 'z', 'A' .. 'Z'
        @current_token.kind = :identifier
        @current_token.append_char(char)
        consume_identifier
        finish_token
      else
        raise "lexer error before #{char} at #{@index}"
      end
    end

    if @current_token.content.size > 0
      puts "Warning: unfinished token after end of lexing"
      finish_token
    end
    @current_token.kind = :eof
    finish_token
  end

  def unread_char
    @index -= 1
  end

  def finish_token
    @tokens << @current_token
    @current_token = Token.new
  end

  def consume_until_end_of_string
    until @index >= @input.size
      char = @input[@index]
      @index += 1

      # TODO: allow escaping

      case char
      when '"'
        @current_token.append_char(char)
        return
      else
        @current_token.append_char(char)
      end
    end
  end

  def consume_space
    until @index >= @input.size
      char = @input[@index]
      @index += 1

      case char
      when ' ', '\t'
        @current_token.append_char(char)
      else
        unread_char
        return
      end
    end
  end

  def consume_identifier
    until @index >= @input.size
      char = @input[@index]
      @index += 1

      case char
      when 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '-', '_'
        @current_token.append_char(char)
      else
        unread_char
        return
      end
    end
  end

  def consume_number
    state = :pre

    until @index >= @input.size
      char = @input[@index]
      @index += 1

      case state
      when :pre
        case char
        when '0'
          @current_token.append_char(char)
          state = :zero
        when '1' .. '9'
          @current_token.append_char(char)
          state = :body
        else
          raise "consume_number: inconsistent lexer state"
        end
      when :zero
        case char
        when 'x', 'b'
          @current_token.append_char(char)
          state = :body
        when '0' .. '9'
          raise "consume_number: lexer error before #{char} at #{@index}"
        else
          unread_char
          return
        end
      when :body
        case char
          # TODO: be more strict
        when '0' .. '9', 'a' .. 'f', 'A' .. 'F'
          @current_token.append_char(char)
        else
          unread_char
          return
        end
      else
        raise "consume_number: inconsistent lexer state"
      end
    end
  end
end

class Sexp
  getter args

  def initialize(args)
    @args = args
  end

  def to_s
    "(#{args.map { |a| a.to_s }.join(' ')})"
  end
end

class Parser
  getter statements

  def initialize(@input)
    @index = 0
    @statements = [] of Sexp
  end

  def run
    loop do
      case current_token.kind
      when :eof
        break
      when :newline, :space
        consume
      else
        @statements << consume_sexp
      end
    end
  end

  def consume_sexp
    consume(:lparen)
    id = consume(:identifier)
    args = [] of Token | Sexp
    loop do
      arg = try_consume_argument
      if arg
        args << arg
      else
        break
      end
    end
    consume(:rparen)
    Sexp.new([id] + args)
  end

  def consume_all_optional_whitespace
    while [:space, :newline].includes?(current_token.kind)
      consume
    end
  end

  def try_consume_argument
    if [:space, :newline].includes?(current_token.kind)
      consume_all_optional_whitespace
      candidate = consume
      case candidate.kind
      when :identifier, :number, :string
        candidate
      when :lparen
        unread_token
        consume_sexp
      else
        raise "Parser: unexpected #{candidate.kind.to_s.upcase}"
      end
    else
      nil
    end
  end

  def advance
    @index += 1
  end

  def unread_token
    @index -= 1
  end

  def current_token
    @input[@index]
  end

  def consume
    @input[@index].tap { advance }
  end

  def consume(kind)
    token = @input[@index]
    if token.kind == kind
      consume
    else
      raise "Parser: unexpected #{token.kind.to_s.upcase}"
    end
  end
end

# (call name arg0 …)
# (while cond body)
# (fn name (arg0 …) body)
# (let name body)
# (print string)
# (print number)
# (halt)

abstract class Tree
end

class PrintNumTree < Tree
  getter num

  def initialize(@num)
  end

  def to_s
    "<PrintNum #{num}>"
  end
end

class PrintRegTree < Tree
  getter identifier

  def initialize(@identifier)
  end

  def to_s
    "<PrintReg #{identifier}>"
  end
end

class HaltTree < Tree
  end

# Translates from sexps into trees
class Translator
  getter trees

  def initialize(@input)
    @index = 0
    @trees = [] of Tree
  end

  def run
    until @index >= @input.size
      handle_sexp(current_sexp)
      advance
    end
  end

  def handle_sexp(sexp)
    first = sexp.args[0]
    case first
    when Token
      case first.content
      when "halt"
        @trees << HaltTree.new
      when "print"
        # TODO: handle strings too
        # TODO: handle all formats of ints
        if sexp.args.size != 2
          raise "Invalid number of arguments for print"
        end

        second = sexp.args[1]
        case second
        when Token
          case second.kind
          when :number
            @trees << PrintNumTree.new(second.content.to_i)
          when :identifier
            @trees << PrintRegTree.new(second.content)
          else
            raise "Invalid argument 2 for print"
          end
        else
          raise "Invalid type for argument 2 for print"
        end
      else
        raise "Unexpected sexp type: #{first.content}"
      end
    else
      raise "Cannot have sexp as first item in a sexp"
    end
  end

  def advance
    @index += 1
  end

  def current_sexp
    @input[@index]
  end
end

class AssemblyWriter
  getter lines

  def initialize(@input)
    @index = 0
    @cur_reg = 0
    @lines = [] of String
  end

  def run
    until @index >= @input.size
      handle_tree(current_tree)
      advance
    end
  end

  def handle_tree(tree)
    case tree
    when PrintNumTree
      reg = new_reg
      @lines << "\taddi r#{reg}, #{tree.num}, 0"
      @lines << "\tprn r#{reg}"
    when PrintRegTree
      @lines << "\tprn #{tree.identifier}"
    when HaltTree
      @lines << "\thalt"
    else
      raise "Unknown tree: #{tree.to_s}"
    end
  end

  def advance
    @index += 1
  end

  def new_reg
    @cur_reg.tap { @cur_reg += 1 }
  end

  def current_tree
    @input[@index]
  end
end

if ARGV.size != 1
  puts "usage: #{$0} [filename"
  exit 1
end

input = File.read(ARGV[0])

lexer = Lexer.new(input)
lexer.run
p lexer.tokens
puts "----------"
puts

parser = Parser.new(lexer.tokens)
parser.run
puts "Statements:"
parser.statements.each { |s| puts s.to_s }
puts "----------"
puts

translator = Translator.new(parser.statements)
translator.run
puts "Trees:"
translator.trees.each { |t| puts t.to_s }
puts "----------"
puts

writer = AssemblyWriter.new(translator.trees)
writer.run
puts "Assembly:"
writer.lines.each { |l| puts l }
