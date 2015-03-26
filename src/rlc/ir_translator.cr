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

module IRTranslator
  abstract class IRTree
  end

  class ConstTree < IRTree
    getter value

    def initialize(@value : Int32)
    end
  end

  class RefTree < IRTree
    getter ref

    def initialize(@ref : Int32)
    end
  end

  class LabelTree < IRTree
    getter name

    def initialize(@name : String)
    end
  end

  class PrintTree < IRTree
    getter tree

    def initialize(@tree : IRTree)
    end
  end

  class HaltTree < IRTree
  end

  class SeqTree < IRTree
    getter a
    getter b

    def initialize(@a : IRTree, @b : IRTree)
    end
  end

  class AssignTree < IRTree
    getter ref
    getter tree

    def initialize(@ref : Int32, @tree : IRTree)
    end
  end

  class IRTranslator
    getter trees

    def initialize(@input)
      @index = 0
      @trees = [] of IRTree
    end

    def run
      until @index >= @input.size
        @trees << translate_expr(current_expr)
        advance
      end
    end

    def translate_expr(expr : Analyser::Expr)
      case expr
      when Analyser::SeqExpr
        SeqTree.new(
          translate_expr(expr.a),
          translate_expr(expr.b))
      when Analyser::HaltExpr
        HaltTree.new
      when Analyser::PrintExpr
        subexpr = expr.expr

        case subexpr
        when Analyser::VarExpr
          PrintTree.new(RefTree.new(subexpr.ref))
        when Analyser::ConstExpr
          PrintTree.new(ConstTree.new(subexpr.value))
        else
          raise "Invalid type for argument 0 for let"
        end
      when Analyser::AssignExpr
        subexpr = expr.expr

        case subexpr
        when Analyser::VarExpr
          AssignTree.new(expr.ref, RefTree.new(subexpr.ref))
        when Analyser::ConstExpr
          AssignTree.new(expr.ref, ConstTree.new(subexpr.value))
        else
          raise "Invalid type for argument 3 for let"
        end
      else
        raise "Unrecognised expr #{expr}"
      end
    end

    def advance
      @index += 1
    end

    def current_expr
      @input[@index]
    end
  end
end
