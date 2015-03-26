class Sexp
  getter args

  def initialize(args)
    @args = args
  end

  def to_s
    "(#{args.map { |a| a.to_s }.join(' ')})"
  end
end

class Parser
  getter statements

  def initialize(@input)
    @index = 0
    @statements = [] of Sexp
  end

  def run
    loop do
      case current_token.kind
      when :eof
        break
      when :newline, :space
        consume
      else
        @statements << consume_sexp
      end
    end
  end

  def consume_sexp
    consume(:lparen)
    id = consume(:identifier)
    args = [] of Token | Sexp
    loop do
      arg = try_consume_argument
      if arg
        args << arg
      else
        break
      end
    end
    consume(:rparen)
    Sexp.new([id] + args)
  end

  def consume_all_optional_whitespace
    while [:space, :newline].includes?(current_token.kind)
      consume
    end
  end

  def try_consume_argument
    if [:space, :newline].includes?(current_token.kind)
      consume_all_optional_whitespace
      candidate = consume
      case candidate.kind
      when :identifier, :number, :string
        candidate
      when :lparen
        unread_token
        consume_sexp
      else
        raise "Parser: unexpected #{candidate.kind.to_s.upcase}"
      end
    else
      nil
    end
  end

  def advance
    @index += 1
  end

  def unread_token
    @index -= 1
  end

  def current_token
    @input[@index]
  end

  def consume
    @input[@index].tap { advance }
  end

  def consume(kind)
    token = @input[@index]
    if token.kind == kind
      consume
    else
      raise "Parser: unexpected #{token.kind.to_s.upcase}"
    end
  end
end
