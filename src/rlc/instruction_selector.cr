module InstructionSelector
  class Name
    getter value

    def initialize(@value : String)
    end

    def to_s
      value
    end
  end

  abstract class Instruction
  end

  class HaltInstr < Instruction
    def to_s
      "[Halt]"
    end
  end

  class LabelInstr < Instruction
    getter name

    def initialize(@name : Name)
    end

    def to_s
      "[Label #{@name.value.to_s}]"
    end
  end

  class PrintInstr < Instruction
    getter name

    def initialize(@name : Name)
    end

    def to_s
      "[Print #{@name.value.to_s}]"
    end
  end

  class LoadImmInstr < Instruction
    getter name
    getter value

    def initialize(@name : Name, @value : Int32)
    end

    def to_s
      "[LoadImm #{@name.value.to_s} #{@value.to_s}]"
    end
  end

  class MovInstr < Instruction
    getter name
    getter value

    def initialize(@name : Name, @value : Name)
    end

    def to_s
      "[Mov #{@name.value.to_s} #{@value.to_s}]"
    end
  end

  class InstructionSelector
    getter instrs

    def initialize(@input)
      @index = 0
      @cur_var = 0
      @instrs = [] of Instruction
    end

    def run
      until @index >= @input.size
        handle_tree(current_tree).each do |instr|
          p instr
          @instrs << instr
        end
        advance
      end
    end

    def handle_tree(tree)
      case tree
      when IRTranslator::HaltTree
        [HaltInstr.new]
      when IRTranslator::LabelTree
        [LabelInstr.new(tree.name)]
      when IRTranslator::PrintTree
        subtree = tree.tree
        case subtree
        when IRTranslator::RefTree
          [PrintInstr.new(Name.new("ref_#{subtree.ref}"))]
        when IRTranslator::ConstTree
          name = new_tmp_name
          [
            LoadImmInstr.new(name, subtree.value),
            PrintInstr.new(name),
          ]
        else
          raise "Impossible subtree"
        end
      when IRTranslator::AssignTree
        ref = tree.ref
        subtree = tree.tree
        case subtree
        when IRTranslator::RefTree
          [MovInstr.new(Name.new("ref_#{ref}"), Name.new("ref_#{subtree.ref}"))]
        when IRTranslator::ConstTree
          [LoadImmInstr.new(Name.new("ref_#{ref}"), subtree.value)]
        else
          raise "Impossible subtree"
        end
      when IRTranslator::SeqTree
        res = [] of Instruction
        handle_tree(tree.a).each { |i| res << i }
        handle_tree(tree.b).each { |i| res << i }
        res
      else
        raise "Unknown tree: #{tree.to_s}"
      end
    end

    def advance
      @index += 1
    end

    def new_tmp_name
      Name.new("tmp_#{@cur_var}").tap { @cur_var += 1 }
    end

    def current_tree
      @input[@index]
    end
  end
end
