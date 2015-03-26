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

  class CmpInstr < Instruction
    getter a
    getter b

    def initialize(@a, @b)
    end

    def to_s
      "[Cmp #{@a.to_s} #{@b.to_s}]"
    end
  end

  class CndJumpInstr < Instruction
    getter op
    getter target

    def initialize(@op, @target)
    end

    def to_s
      "[CndJump #{@op.to_s} #{@target.to_s}]"
    end
  end

  class JumpInstr < Instruction
    getter target

    def initialize(@target)
    end

    def to_s
      "[Jump #{@target.to_s}]"
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
      when IRTranslator::CndJumpTree
        label_true  = new_tmp_name
        label_false = new_tmp_name
        label_done  = new_tmp_name
        res = [] of Instruction
        res << CndJumpInstr.new(:eq, label_true)
        res << JumpInstr.new(label_false)
        res << LabelInstr.new(label_true)
        handle_tree(tree.body).each { |i| res << i }
        res << JumpInstr.new(label_done)
        res << LabelInstr.new(label_false)
        # TODO: add false
        res << JumpInstr.new(label_done)
        res << LabelInstr.new(label_done)
        res
      when IRTranslator::CmpTree
        a = tree.a
        b = tree.b
        unless a.is_a?(IRTranslator::RefTree)
          raise "First arg for cmp can only be ref"
        end

        case b
        when IRTranslator::ConstTree
          [CmpInstr.new(Name.new("ref_#{a.ref}"), b.value)]
        when IRTranslator::RefTree
          [CmpInstr.new(Name.new("ref_#{a.ref}"), Name.new("ref_#{b.ref}"))]
        else
          raise "Second tree can be const and ref, but found neither"
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
