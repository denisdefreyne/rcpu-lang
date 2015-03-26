module Lexer
  class Token
    property kind

    def initialize
      @kind = :unknown
      @content_io = StringIO.new
    end

    def empty
      @content_io = StringIO.new
    end

    def append_char(c)
      @content_io << c
    end

    def content
      @content_io.to_s
    end

    def to_s
      content + "#" + kind.to_s
    end

    def inspect(io)
      io << to_s
    end
  end

  class Lexer
    getter tokens

    def initialize(@input)
      @index = 0
      @tokens = [] of Token
      @current_token = Token.new
    end

    def run
      until @index >= @input.size
        char = @input[@index]
        @index += 1

        case char
        when '('
          @current_token.kind = :lparen
          @current_token.empty
          finish_token
        when ')'
          @current_token.kind = :rparen
          @current_token.empty
          finish_token
        when ' ', '\t'
          @current_token.kind = :space
          @current_token.append_char(char)
          consume_space
          finish_token
        when '\n'
          @current_token.kind = :newline
          @current_token.empty
          finish_token
        when '"'
          @current_token.kind = :string
          @current_token.append_char(char)
          consume_until_end_of_string
          finish_token
        when '0' .. '9'
          @current_token.kind = :number
          unread_char # input required for decision making
          consume_number
          finish_token
        when 'a' .. 'z', 'A' .. 'Z'
          @current_token.kind = :identifier
          @current_token.append_char(char)
          consume_identifier
          finish_token
        else
          raise "lexer error before #{char} at #{@index}"
        end
      end

      if @current_token.content.size > 0
        puts "Warning: unfinished token after end of lexing"
        finish_token
      end
      @current_token.kind = :eof
      finish_token
    end

    def unread_char
      @index -= 1
    end

    def finish_token
      @tokens << @current_token
      @current_token = Token.new
    end

    def consume_until_end_of_string
      until @index >= @input.size
        char = @input[@index]
        @index += 1

        # TODO: allow escaping

        case char
        when '"'
          @current_token.append_char(char)
          return
        else
          @current_token.append_char(char)
        end
      end
    end

    def consume_space
      until @index >= @input.size
        char = @input[@index]
        @index += 1

        case char
        when ' ', '\t'
          @current_token.append_char(char)
        else
          unread_char
          return
        end
      end
    end

    def consume_identifier
      until @index >= @input.size
        char = @input[@index]
        @index += 1

        case char
        when 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '-', '_'
          @current_token.append_char(char)
        else
          unread_char
          return
        end
      end
    end

    def consume_number
      state = :pre

      until @index >= @input.size
        char = @input[@index]
        @index += 1

        case state
        when :pre
          case char
          when '0'
            @current_token.append_char(char)
            state = :zero
          when '1' .. '9'
            @current_token.append_char(char)
            state = :body_dec
          else
            raise "consume_number: inconsistent lexer state"
          end
        when :zero
          case char
          when 'x'
            @current_token.append_char(char)
            state = :body_hex
          when 'b'
            @current_token.append_char(char)
            state = :body_bin
          when '0' .. '7'
            unread_char
            state = :body_oct
          else
            unread_char
            return
          end
        when :body_dec
          case char
          when '0' .. '9'
            @current_token.append_char(char)
          else
            unread_char
            return
          end
        when :body_hex
          case char
          when '0' .. '9', 'a' .. 'f', 'A' .. 'F'
            @current_token.append_char(char)
          else
            unread_char
            return
          end
        when :body_bin
          case char
          when '0' .. '1'
            @current_token.append_char(char)
          else
            unread_char
            return
          end
        when :body_oct
          case char
          when '0' .. '7'
            @current_token.append_char(char)
          else
            unread_char
            return
          end
        else
          raise "consume_number: inconsistent lexer state"
        end
      end
    end
  end
end
