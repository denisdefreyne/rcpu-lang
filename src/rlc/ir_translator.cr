# (call name arg0 …)
# (while cond body)
# (fn name (arg0 …) body)
# (let name body)
# (print string)
# (print number)
# (halt)
# (if cond body-true body-false)

abstract class IRTree
end

class PrintTree < IRTree
  getter reg

  def initialize(@reg)
  end

  def to_s
    "<Print #{reg}>"
  end
end

class HaltTree < IRTree
  def to_s
    "<Halt>"
  end
end

class LoadImmTree < IRTree
  getter identifier
  getter value

  def initialize(@identifier, @value)
  end

  def to_s
    "<LoadImm #{identifier} #{value}>"
  end
end

class MovTree < IRTree
  getter target_identifier
  getter source_identifier

  def initialize(@target_identifier, @source_identifier)
  end

  def to_s
    "<Mov #{target_identifier} #{source_identifier}>"
  end
end

class CmpTree < IRTree
  getter a
  getter b

  def initialize(@a, @b)
  end

  def to_s
    "<Cmp #{a} #{b}>"
  end
end

class JeiTree < IRTree
  getter name

  def initialize(@name)
  end

  def to_s
    "<Jei #{name}>"
  end
end

class JiTree < IRTree
  getter name

  def initialize(@name)
  end

  def to_s
    "<Ji #{name}>"
  end
end

class LabelTree < IRTree
  getter name

  def initialize(@name)
  end

  def to_s
    "<Label #{name}>"
  end
end

# Translates from sexps into trees
#
# TODO: rename Tree to UnboundInstruction
# TODO: Reuse tree to simplify AST (move sexps in separate vars etc)
class IRTranslator
  getter trees

  def initialize(@input)
    @index = 0
    @trees = [] of IRTree
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
