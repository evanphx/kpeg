module KPeg
  class CompiledGrammar
    def initialize(str)
      @string = str
      @pos = 0
      @memoizations = Hash.new { |h,k| h[k] = {} }
      @result = nil
      @text = nil
    end

    attr_reader :result, :text
    attr_accessor :pos

    def set_text(start)
      @text = @string[start..@pos-1]
    end

    def show_pos
      if @pos < 5
        "#{@pos} (\"#{@string[0,@pos]}\" @ \"#{@string[@pos,5]}\")"
      else
        "#{@pos} (\"#{@string[@pos - 5, 5]}\" @ \"#{@string[@pos,5]}\")"
      end
    end

    def match_string(str)
      len = str.size
      if @string[pos,len] == str
        @pos += len
        return str
      end

      return nil
    end

    def unget_byte(str)
      @pos -= str.size
    end

    def scan(reg)
      if m = reg.match(@string[@pos..-1])
        width = m.end(0)
        @pos += width
        return true
      end

      return nil
    end

    def get_byte
      return nil if @pos >= @string.size
      s = @string[@pos,1]
      @pos += 1
      s
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
      if m = @memoizations[rule][@pos]
        m.inc!

        @pos = m.pos
        if m.ans.kind_of? LeftRecursive
          m.ans.detected = true
          return nil
        end

        return m.ans
      else
        lr = LeftRecursive.new(false)
        m = MemoEntry.new(lr, @pos)
        @memoizations[rule][@pos] = m
        start_pos = @pos

        ans = __send__ method_name

        m.move! ans, @pos

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
        @pos = start_pos
        ans = __send__ method_name
        return nil unless ans

        break if @pos <= m.pos

        m.move! ans, @pos
      end

      @pos = m.pos
      return m.ans
    end
  end
end
