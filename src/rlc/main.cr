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

translator = IRTranslator::IRTranslator.new(parser.statements)
translator.run

selector = InstructionSelector::InstructionSelector.new(translator.trees)
selector.run

writer = AssemblyWriter::AssemblyWriter.new(selector.instrs)
writer.run
writer.lines.each { |l| puts l.to_s }
