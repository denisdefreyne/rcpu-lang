require "./lexer"
require "./parser"
require "./ir_translator"

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

translator = IRTranslator.new(parser.statements)
translator.run

writer = AssemblyWriter.new(translator.trees)
writer.run
writer.lines.each { |l| puts l }
