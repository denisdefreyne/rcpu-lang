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
    case sexp.name
    when "seq"
      sexp.args.each do |sub_sexp|
        unless sub_sexp.is_a?(Parser::Sexp)
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
      if sexp.args.size != 3
        raise "Invalid number of arguments for if-eq"
      end

      a1 = sexp.args[0]
      a2 = sexp.args[1]
      a3 = sexp.args[2]

      case a1
      when Parser::IdentifierSexpArg
      else
        raise "blah"
      end

      case a2
      when Parser::IdentifierSexpArg
      else
        raise "blah"
      end

      case a3
      when Parser::Sexp
      else
        raise "blah"
      end

      label_true = new_name
      label_final = new_name

      @trees << CmpTree.new(@vars[a1.value], @vars[a2.value])
      @trees << JeiTree.new(label_true)
      @trees << JiTree.new(label_final)
      @trees << LabelTree.new(label_true)
      handle_sexp(a3)
      @trees << LabelTree.new(label_final)
    when "let"
      # (let var var)
      # (let var num)
      if sexp.args.size != 2
        raise "Invalid number of arguments for let"
      end

      a1 = sexp.args[0]
      a2 = sexp.args[1]

      case a1
      when Parser::IdentifierSexpArg
        if @vars.has_key?(a1.value)
          raise "Cannot reassign #{a1.value}"
        end
        # FIXME: #to_s should not be necessary here
        @vars[a1.value.to_s] = new_reg

        case a2
        when Parser::IdentifierSexpArg
          unless @vars.has_key?(a2.value)
            raise "Undefined var #{a2.value}"
          end

          @trees << MovTree.new(@vars[a1.value], @vars[a2.value])
        when Parser::NumSexpArg
          # TODO: handle all formats of ints
          @trees << LoadImmTree.new(@vars[a1.value], a2.value)
        else
          raise "Invalid type for argument 3 for let"
        end
      else
        raise "First argument to let must be identifier"
      end
    when "print"
      # (print num)
      # (print var)
      if sexp.args.size != 1
        raise "Invalid number of arguments for print"
      end

      a1 = sexp.args[0]

      case a1
      when Parser::NumSexpArg
        reg = new_reg
        name = new_name
        @vars[name] = reg
        @trees << LoadImmTree.new(reg, a1.value)
        @trees << PrintTree.new(reg)
      when Parser::IdentifierSexpArg
        unless @vars.has_key?(a1.value)
          raise "Undefined var #{a1.value}"
        end

        @trees << PrintTree.new(@vars[a1.value])
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
