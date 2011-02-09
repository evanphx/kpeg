require 'strscan'

module KPeg
  class CompiledGrammar
    def initialize(str)
      @string = str
      @scanner = StringScanner.new(str)
      @memoizations = Hash.new { |h,k| h[k] = {} }
      @result = nil
      @text = nil
    end

    attr_reader :result, :text

    def set_text(start)
      @text = @string[start..@scanner.pos-1]
    end

    def match_string(str)
      len = str.size
      if @scanner.peek(len) == str
        @scanner.pos = @scanner.pos + len
        return str
      end

      return nil
    end

    def unget_byte(str)
      @scanner.pos -= str.size
    end

    def scan(reg)
      @scanner.scan(reg)
    end

    def get_byte
      @scanner.get_byte
    end

    def pos
      @scanner.pos
    end

    def pos=(x)
      @scanner.pos = x
    end

    def run
      _root
    end

    class LeftRecursive
      def initialize(detected=false)
        @detected = detected
      end

      attr_accessor :detected
    end

    class MemoEntry
      def initialize(ans, pos)
        @ans = ans
        @pos = pos
        @uses = 1
      end

      attr_reader :ans, :pos, :uses

      def inc!
        @uses += 1
      end

      def move!(ans, pos)
        @ans = ans
        @pos = pos
      end
    end

    def apply(rule, method_name)
      if m = @memoizations[rule][@scanner.pos]
        m.inc!

        @scanner.pos = m.pos
        if m.ans.kind_of? LeftRecursive
          m.ans.detected = true
          return nil
        end

        return m.ans
      else
        lr = LeftRecursive.new(false)
        m = MemoEntry.new(lr, @scanner.pos)
        @memoizations[rule][@scanner.pos] = m
        start_pos = @scanner.pos

        ans = __send__ method_name

        m.move! ans, @scanner.pos

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr.detected
          return grow_lr(rule, method_name, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def grow_lr(rule, method_name, start_pos, m)
      while true
        @scanner.pos = start_pos
        ans = __send__ method_name
        return nil unless ans

        break if @scanner.pos <= m.pos

        m.move! ans, @scanner.pos
      end

      @scanner.pos = m.pos
      return m.ans
    end
  end
end
