module Analyser
  abstract class Expr
  end

  class ConstExpr < Expr
    getter value

    def initialize(@value : Int32)
    end

    def inspect
      "<Const #{value.inspect}>"
    end
  end

  class VarExpr < Expr
    getter ref

    def initialize(@ref : Int32)
    end

    def inspect
      "<Var #{ref.inspect}>"
    end
  end

  class PrintExpr < Expr
    getter expr

    def initialize(@expr : Expr)
    end

    def inspect
      "<Print #{expr.inspect}>"
    end
  end

  class HaltExpr < Expr
  end

  class SeqExpr < Expr
    getter a
    getter b

    def initialize(@a : Expr, @b : Expr)
    end

    def inspect
      "<Seq #{a.inspect} #{b.inspect}>"
    end
  end

  class AssignExpr < Expr
    getter ref
    getter expr

    def initialize(@ref : Int32, @expr : Expr)
    end

    def inspect
      "<Assign #{ref.inspect} #{expr.inspect}>"
    end
  end

  class IfExpr < Expr
    OP_EQ  = :eq
    OP_NEQ = :neq
    OP_GT  = :gt
    OP_GTE = :gte
    OP_LT  = :lt
    OP_LTE = :lte

    getter op
    getter a
    getter b
    getter body_true
    getter body_false

    def initialize(@op : Op, @a : Expr, @b : Expr, @body_true : Expr, @body_false : Expr | Nil)
    end

    def inspect
      "<If #{op} #{a.inspect} #{b.inspect} #{body_true.inspect} #{body_false.inspect}>"
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
        if sexp.args.size < 2
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

        seq_expr =
          SeqExpr.new(
            analyse_sexp(a0),
            analyse_sexp(a1))

        sexp.args[2..-1].inject(seq_expr) do |seq_expr, arg|
          unless arg.is_a?(Parser::Sexp)
            raise "Invalid type for argument for seq"
          end

          SeqExpr.new(
            seq_expr,
            analyse_sexp(arg))
        end
      when "scoped-seq"
        if sexp.args.size < 2
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

        @envs = EnvStack.new(@envs)

        seq_expr =
          SeqExpr.new(
            analyse_sexp(a0),
            analyse_sexp(a1))

        seq_expr_2 = sexp.args[2..-1].inject(seq_expr) do |seq_expr, arg|
          unless arg.is_a?(Parser::Sexp)
            raise "Invalid type for argument for seq"
          end

          SeqExpr.new(
            seq_expr,
            analyse_sexp(arg))
        end

        @envs = @envs.prev!

        seq_expr_2
      when "halt"
        if sexp.args.size != 0
          raise "Invalid number of arguments for halt"
        end

        HaltExpr.new
      when "if"
        # (if op a b body)

        if sexp.args.size < 4 || sexp.args.size > 5
          raise "Invalid number of arguments for if"
        end

        arg_op         = sexp.args[0]
        arg_a          = sexp.args[1]
        arg_b          = sexp.args[2]
        arg_body_true  = sexp.args[3]
        arg_body_false = sexp.args[4]

        # TODO: set op
        op = :eq

        a_expr =
          case arg_a
          when Parser::IdentifierSexpArg
            right_ref = @envs[arg_a.value]
            VarExpr.new(right_ref)
          when Parser::NumSexpArg
            ConstExpr.new(arg_a.value)
          else
            raise "Invalid type for argument 1 for if"
          end

        b_expr =
          case arg_b
          when Parser::IdentifierSexpArg
            right_ref = @envs[arg_b.value]
            VarExpr.new(right_ref)
          when Parser::NumSexpArg
            ConstExpr.new(arg_b.value)
          else
            raise "Invalid type for argument 2 for if"
          end

        unless arg_body_true.is_a?(Parser::Sexp)
          raise "Invalid type for argument 3 for seq"
        end
        body_true_expr = analyse_sexp(arg_body_true)

        body_false_expr =
          if arg_body_false
            unless arg_body_false.is_a?(Parser::Sexp)
              raise "Invalid type for argument 4 for seq"
            end

            analyse_sexp(arg_body_false)
          else
            nil
          end

        IfExpr.new(op, a_expr, b_expr, body_true_expr, body_false_expr)
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
