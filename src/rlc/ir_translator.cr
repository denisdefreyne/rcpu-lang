# abstract syntax:
#   (call name arg0 …)
#   (while cond body)
#   (fn name (arg0 …) body)
#   (let name body)
#   (print string)
#   (print number)
#   (halt)
#   (if cond body-true body-false)
#   (eq a b)
#   (neq a b)
#   (gt a b)

# IR expressions:
#   const(int)
#   const(string)
#   name(string)
#   temp(string)
#   label(string)
#   mem(exp)
#   call(name, exp1, …)
# IR statements:
#   halt()
#   print(exp)
#   eval(exp)
#   move(temp, exp)
#   jump(name)
#   cjump(oper, exp1, exp2, name_true, name_false)
#   seq(exp1, exp2)

abstract class IRTree
  def to_s
    String.build { |io| fmt(io, 0) }
  end

  def fmt(io, indent = 0)
    indent.times { io << "  " }
    io << "???"
  end
end

class ConstTree < IRTree
  getter value

  def initialize(@value : Int32)
  end

  def fmt(io, indent = 0)
    indent.times { io << "  " }
    io << "<Const #{value.to_s}>"
  end
end

class NameTree < IRTree
  getter value

  def initialize(@value : String)
  end

  def fmt(io, indent = 0)
    indent.times { io << "  " }
    io << "<Name #{value.to_s}>"
  end
end

class LabelTree < IRTree
  getter name

  def initialize(@name : String)
  end

  def fmt(io, indent = 0)
    indent.times { io << "  " }
    io << "<Label\n"
    name.fmt(io, indent + 1)
    io << ">"
  end
end

class PrintTree < IRTree
  getter tree

  def initialize(@tree : IRTree)
  end

  def fmt(io, indent = 0)
    indent.times { io << "  " }
    io << "<Print\n"
    tree.fmt(io, indent + 1)
    io << ">"
  end
end

class HaltTree < IRTree
  def fmt(io, indent = 0)
    indent.times { io << "  " }
    io << "<Halt>"
  end
end

class SeqTree < IRTree
  getter a
  getter b

  def initialize(@a : IRTree, @b : IRTree)
  end

  def fmt(io, indent = 0)
    indent.times { io << "  " }
    io << "<Seq\n"
    a.fmt(io, indent + 1)
    io << "\n"
    b.fmt(io, indent + 1)
    io << ">"
  end
end

class AssignTree < IRTree
  getter name
  getter tree

  def initialize(@name : NameTree, @tree : IRTree)
  end

  def fmt(io, indent = 0)
    indent.times { io << "  " }
    io << "<Assign\n"
    name.fmt(io, indent + 1)
    io << "\n"
    tree.fmt(io, indent + 1)
    io << ">"
  end
end

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
      @trees << translate_sexp(current_sexp)
      advance
    end
  end

  def translate_sexp(sexp : Parser::Sexp)
    case sexp.name
    when "seq"
      # (seq a b)

      # TODO: allow arbitrary number
      if sexp.args.size != 2
        raise "Invalid number of arguments for seq"
      end

      a0 = sexp.args[0]
      a1 = sexp.args[1]

      unless a0.is_a?(Parser::Sexp)
        raise "Invalid type for argument 0 for seq"
      end

      unless a1.is_a?(Parser::Sexp)
        raise "Invalid type for argument 1 for seq"
      end

      SeqTree.new(
        translate_sexp(a0),
        translate_sexp(a1))
    when "halt"
      HaltTree.new
    when "print"
      # (print var)
      # (print num)

      if sexp.args.size != 1
        raise "Invalid number of arguments for let"
      end

      a0 = sexp.args[0]

      case a0
      when Parser::IdentifierSexpArg
        PrintTree.new(NameTree.new(a0.value))
      when Parser::NumSexpArg
        PrintTree.new(ConstTree.new(a0.value))
      else
        raise "Invalid type for argument 0 for let"
      end
    when "let"
      # (let var var)
      # (let var num)

      if sexp.args.size != 2
        raise "Invalid number of arguments for let"
      end

      a0 = sexp.args[0]
      a1 = sexp.args[1]

      unless a0.is_a?(Parser::IdentifierSexpArg)
        raise "Invalid type for argument 0 for let"
      end

      case a1
      when Parser::IdentifierSexpArg
        AssignTree.new(NameTree.new(a0.value), NameTree.new(a1.value))
      when Parser::NumSexpArg
        AssignTree.new(NameTree.new(a0.value), ConstTree.new(a1.value))
      else
        raise "Invalid type for argument 3 for let"
      end
    else
      raise "Unrecognised sexp name #{sexp.name}"
    end
  end

  def advance
    @index += 1
  end

  def current_sexp
    @input[@index]
  end

  # def new_name
  #   NameTree.new("n#{@cur_name_id}").tap { @cur_name_id += 1 }
  # end
end
