require "./lexer"
require "./parser"
require "./ir_translator"
require "./instruction_selector"

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

writer = InstructionSelector::InstructionSelector.new(translator.trees)
writer.run
writer.instrs.each { |i| puts i.to_s }
