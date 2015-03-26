module Analyser
  abstract class Expr
  end

  class ConstExpr < Expr
    getter value

    def initialize(@value : Int32)
    end
  end

  class VarExpr < Expr
    getter name

    def initialize(@name : String)
    end
  end

  class PrintExpr < Expr
    getter expr

    def initialize(@expr : Expr)
    end
  end

  class HaltExpr < Expr
  end

  class SeqExpr < Expr
    getter a
    getter b

    def initialize(@a : Expr, @b : Expr)
    end
  end

  class AssignExpr < Expr
    getter name
    getter expr

    def initialize(@name : String, @expr : Expr)
    end
  end

  class Analyser
    getter exprs

    def initialize(@input)
      @index = 0
      @exprs = [] of Expr
    end

    def run
      until @index >= @input.size
        @exprs << analyse_sexp(current_sexp)
        advance
      end
    end

    def analyse_sexp(sexp : Parser::Sexp)
      case sexp.name
      when "seq"
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

        SeqExpr.new(
          analyse_sexp(a0),
          analyse_sexp(a1))
      when "halt"
        if sexp.args.size != 0
          raise "Invalid number of arguments for halt"
        end

        HaltExpr.new
      when "print"
        # (print var)
        # (print num)

        if sexp.args.size != 1
          raise "Invalid number of arguments for print"
        end

        a0 = sexp.args[0]

        case a0
        when Parser::IdentifierSexpArg
          PrintExpr.new(VarExpr.new(a0.value))
        when Parser::NumSexpArg
          PrintExpr.new(ConstExpr.new(a0.value))
        else
          raise "Invalid type for argument 0 for print"
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
          AssignExpr.new(a0.value, VarExpr.new(a1.value))
        when Parser::NumSexpArg
          AssignExpr.new(a0.value, ConstExpr.new(a1.value))
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
  end
end
