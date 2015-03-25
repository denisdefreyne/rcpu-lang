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
# (if cond body-true body-false)

abstract class Tree
end

class PrintTree < Tree
  getter reg

  def initialize(@reg)
  end

  def to_s
    "<PrintReg #{reg}>"
  end
end

class HaltTree < Tree
  def to_s
    "<Halt>"
  end
end

class LoadImmTree < Tree
  getter identifier
  getter value

  def initialize(@identifier, @value)
  end

  def to_s
    "<LoadImm #{identifier} #{value}>"
  end
end

class MovTree < Tree
  getter target_identifier
  getter source_identifier

  def initialize(@target_identifier, @source_identifier)
  end

  def to_s
    "<Mov #{target_identifier} #{source_identifier}>"
  end
end

class CmpTree < Tree
  getter a
  getter b

  def initialize(@a, @b)
  end

  def to_s
    "<Cmp #{a} #{b}>"
  end
end

class JeiTree < Tree
  getter name

  def initialize(@name)
  end

  def to_s
    "<JeiTree #{name}>"
  end
end

class JiTree < Tree
  getter name

  def initialize(@name)
  end

  def to_s
    "<JiTree #{name}>"
  end
end

class LabelTree < Tree
  getter name

  def initialize(@name)
  end

  def to_s
    "<LabelTree #{name}>"
  end
end

# Translates from sexps into trees
#
# TODO: rename Tree to UnboundInstruction
# TODO: Reuse tree to simplify AST (move sexps in separate vars etc)
class Translator
  getter trees

  def initialize(@input)
    @index = 0
    @trees = [] of Tree
    @vars = {} of String => Int32 # Name to register
    @cur_reg = 0
    @cur_name_id = 0
  end

  def run
    until @index >= @input.size
      handle_sexp(current_sexp)
      advance
    end
  end

  def handle_sexp(sexp)
    a0 = sexp.args[0]
    unless a0.is_a?(Token)
      raise "Cannot have sexp as a0 item in a sexp"
    end

    case a0.content
    when "seq"
      sexp.args[1..-1].each do |sub_sexp|
        unless sub_sexp.is_a?(Sexp)
          raise "Can only have sexps in seq"
        end

        handle_sexp(sub_sexp)
      end
    when "halt"
      @trees << HaltTree.new
    when "if-eq"
      # (if-eq a b body)
      # TODO: also add false body
      # TODO: add more than just if-eq
      if sexp.args.size != 4
        raise "Invalid number of arguments for if-eq"
      end

      a1 = sexp.args[1]
      a2 = sexp.args[2]
      a3 = sexp.args[3]
      unless a1.is_a?(Token)
        raise "Invalid type for argument 2 for if-eq"
      end
      unless a2.is_a?(Token)
        raise "Invalid type for argument 3 for if-eq"
      end
      unless a3.is_a?(Sexp)
        raise "Invalid type for argument 4 for if-eq"
      end

      label_true = new_name
      label_final = new_name

      @trees << CmpTree.new(@vars[a1.content], @vars[a2.content])
      @trees << JeiTree.new(label_true)
      @trees << JiTree.new(label_final)
      @trees << LabelTree.new(label_true)
      handle_sexp(a3)
      @trees << LabelTree.new(label_final)
    when "let"
      # (let var var)
      # (let var num)
      if sexp.args.size != 3
        raise "Invalid number of arguments for let"
      end

      a1 = sexp.args[1]
      a2 = sexp.args[2]
      unless a1.is_a?(Token)
        raise "Invalid type for argument 2 for let"
      end
      unless a2.is_a?(Token)
        raise "Invalid type for argument 3 for let"
      end
      unless a1.kind == :identifier
        raise "Invalid type for argument 2 for let"
      end

      if @vars.has_key?(a1.content)
        raise "Cannot reassign #{a1.content}"
      end
      @vars[a1.content] = new_reg

      case a2.kind
      when :identifier
        unless @vars.has_key?(a2.content)
          raise "Undefined var #{a2.content}"
        end

        @trees << MovTree.new(@vars[a1.content], @vars[a2.content])
      when :number
        # TODO: handle all formats of ints
        @trees << LoadImmTree.new(@vars[a1.content], a2.content.to_i)
      else
        raise "Invalid type for argument 3 for let"
      end
    when "print"
      # (print num)
      # (print var)
      if sexp.args.size != 2
        raise "Invalid number of arguments for print"
      end

      a1 = sexp.args[1]
      unless a1.is_a?(Token)
        raise "Invalid type for argument 2 for print"
      end

      case a1.kind
      when :number
        # TODO: handle all formats of ints
        # TODO: assign to reg and then print
        reg = new_reg
        name = new_name
        @vars[name] = reg
        @trees << LoadImmTree.new(reg, a1.content.to_i)
        @trees << PrintTree.new(reg)
      when :identifier
        unless @vars.has_key?(a1.content)
          raise "Undefined var #{a1.content}"
        end

        @trees << PrintTree.new(@vars[a1.content])
      else
        raise "Invalid argument 2 for print"
      end
    end
  end

  def advance
    @index += 1
  end

  def current_sexp
    @input[@index]
  end

  def new_name
    "tmp_#{@cur_name_id}".tap { @cur_name_id += 1 }
  end

  def new_reg
    @cur_reg.tap { @cur_reg += 1 }
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
    when LabelTree
      @lines << "#{tree.name}:"
    when LoadImmTree
      @lines << "\tli r#{tree.identifier}, #{tree.value}"
    when MovTree
      @lines << "\tmov r#{tree.target_identifier}, r#{tree.source_identifier}"
    when CmpTree
      # TODO: CmpiTree
      @lines << "\tcmp r#{tree.a}, r#{tree.b}"
    when JeiTree
      @lines << "\tjei @#{tree.name}"
    when JiTree
      @lines << "\tji @#{tree.name}"
    when PrintTree
      @lines << "\tprn r#{tree.reg}"
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
  puts "usage: #{$0} [filename]"
  exit 1
end

input = File.read(ARGV[0])

lexer = Lexer.new(input)
lexer.run

parser = Parser.new(lexer.tokens)
parser.run
parser.statements.each { |s| puts "#" + s.to_s }

translator = Translator.new(parser.statements)
translator.run

writer = AssemblyWriter.new(translator.trees)
writer.run
writer.lines.each { |l| puts l }
