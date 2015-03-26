module AssemblyWriter
  class AssemblyWriter
    getter lines

    def initialize(@input)
      @index = 0
      @cur_reg = 0
      @names = {} of String => Int32
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
        reg = find_reg(instr.name.value)
        @lines << "\tprn r#{reg}"
      when InstructionSelector::LoadImmInstr
        reg = find_or_create_reg(instr.name.value)
        @lines << "\tli r#{reg}, #{instr.value}"
      when InstructionSelector::MovInstr
        reg0 = find_or_create_reg(instr.name.value)
        reg1 = find_reg(instr.value.value)
        @lines << "\tmov r#{reg0}, r#{reg1}"
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

    def find_reg(name)
      if @names.has_key?(name)
        @names[name]
      else
        raise "Unknown name: #{name}"
      end
    end

    def find_or_create_reg(name)
      if @names.has_key?(name)
        @names[name]
      else
        @names[name] = @cur_reg
        @cur_reg.tap { @cur_reg += 1 }
      end
    end
  end
end
