module Analyser
  abstract class Expr
  end

  class ConstExpr < Expr
    getter value

    def initialize(@value : Int32)
    end
  end

  class VarExpr < Expr
    getter ref

    def initialize(@ref : Int32)
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
    getter ref
    getter expr

    def initialize(@ref : Int32, @expr : Expr)
    end
  end

  class Env
    def initialize
      @wrapped = {} of String => Int32
    end

    def has_key?(key : String)
      @wrapped.has_key?(key)
    end

    def [](key : String)
      if @wrapped.has_key?(key)
        @wrapped[key]
      else
        raise "Unknown name #{key}"
      end
    end

    def []=(key : String, value : Int32)
      if has_key?(key)
        raise "Key #{key} already taken"
      else
        @wrapped[key] = value
      end
    end
  end

  class EnvStack
    def initialize(@prev = nil)
      @env = Env.new
    end

    def [](key : String)
      if @env.has_key?(key)
        return @env[key]
      end

      prev = @prev
      if prev
        return prev[key]
      end

      raise "Unknown name #{key}"
    end

    def has_prev?
      !@prev.nil?
    end

    def prev!
      prev = @prev
      if prev
        prev
      else
        raise "Cannot get prev of empty stack"
      end
    end

    def []=(key : String, value : Int32)
      @env[key] = value
    end
  end

  class Analyser
    getter exprs

    def initialize(@input)
      @index = 0
      @exprs = [] of Expr
      @envs = EnvStack.new
      @ref_id = 0
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
      when "scope"
        # TODO: allow arbitrary number
        if sexp.args.size != 2
          raise "Invalid number of arguments for scope"
        end

        a0 = sexp.args[0]
        a1 = sexp.args[1]

        unless a0.is_a?(Parser::Sexp)
          raise "Invalid type for argument 0 for scope"
        end

        unless a1.is_a?(Parser::Sexp)
          raise "Invalid type for argument 1 for scope"
        end

        @envs = EnvStack.new(@envs)
        s = SeqExpr.new(
          analyse_sexp(a0),
          analyse_sexp(a1))
        @envs = @envs.prev!
        s
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
          right_ref = @envs[a0.value]
          PrintExpr.new(VarExpr.new(right_ref))
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

        @envs[a0.value] = new_ref

        case a1
        when Parser::IdentifierSexpArg
          right_ref = @envs[a1.value]
          AssignExpr.new(@envs[a0.value], VarExpr.new(right_ref))
        when Parser::NumSexpArg
          AssignExpr.new(@envs[a0.value], ConstExpr.new(a1.value))
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

    def new_ref
      @ref_id.tap { @ref_id += 1 }
    end
  end
end
