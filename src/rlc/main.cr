require "./lexer"
require "./parser"
require "./ir_translator"
require "./instruction_selector"
require "./assembly_writer"

if ARGV.size != 1
  puts "usage: #{$0} [filename]"
  exit 1
end

input = File.read(ARGV[0])

lexer = Lexer::Lexer.new(input)
lexer.run

parser = Parser::Parser.new(lexer.tokens)
parser.run
parser.statements.each { |s| puts "#" + s.to_s }

translator = IRTranslator::IRTranslator.new(parser.statements)
translator.run
translator.trees.each { |t| puts t.to_s }

selector = InstructionSelector::InstructionSelector.new(translator.trees)
selector.run
selector.instrs.each { |i| puts i.to_s }

writer = AssemblyWriter::AssemblyWriter.new(selector.instrs)
writer.run
writer.lines.each { |l| puts l.to_s }
