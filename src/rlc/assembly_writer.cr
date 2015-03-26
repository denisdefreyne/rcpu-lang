module AssemblyWriter
  class AssemblyWriter
    getter lines

    def initialize(@input)
      @index = 0
      @cur_var = 0
      @lines = [] of String
    end

    def run
      until @index >= @input.size
        handle_instr(current_instr)
        advance
      end
    end

    def handle_instr(instr)
      case instr
      when InstructionSelector::HaltInstr
        @lines << "\thalt"
      when InstructionSelector::LabelInstr
        @lines << "#{instr.name.to_s}:"
      when InstructionSelector::PrintInstr
        @lines << "\tprn #{instr.name.value}"
      when InstructionSelector::LoadImmInstr
        @lines << "\tli #{instr.name.value}, #{instr.value}"
      when InstructionSelector::MovInstr
        @lines << "\tmov #{instr.name.value}, #{instr.value.value}"
      else
        raise "Unknown instr: #{instr.to_s}"
      end
    end

    def advance
      @index += 1
    end

    def current_instr
      @input[@index]
    end
  end
end
