require 'kpeg/position'

module KPeg
  class Parser < StringScanner
    def initialize(str, grammar, log=false)
      super str

      @grammar = grammar
      # A 2 level hash.
      @memoizations = Hash.new { |h,k| h[k] = {} }

      @failing_offset = nil
      @failing_op = nil
      @log = log
    end

    attr_reader :grammar, :memoizations, :failing_offset
    attr_accessor :failing_op

    include Position

    def switch_grammar(gram)
      begin
        old = @grammar
        @grammar = gram
        yield
      ensure
        @grammar = old
      end
    end

    def fail(op)
      @failing_offset = pos
      @failing_op = op
      return nil
    end

    def expected_string
      case @failing_op
      when Choice
        return Range.new(@failing_op.start, @failing_op.fin)
      when Dot
        return nil
      else
        @failing_op.string
      end
    end

    def show_error

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

    # Call a rule without memoization
    def invoke(rule)
      rule.op.match(self)
    end

    def apply(rule)
      ans = nil
      if m = @memoizations[rule][pos]
        m.inc!

        self.pos = m.pos
        if m.ans.kind_of? LeftRecursive
          m.ans.detected = true
          if @log
            puts "LR #{rule.name} @ #{self.inspect}"
          end
          return nil
        end

        ans = m.ans
      else
        lr = LeftRecursive.new(false)
        m = MemoEntry.new(lr, pos)
        @memoizations[rule][pos] = m
        start_pos = pos

        if @log
          puts "START #{rule.name} @ #{self.inspect}"
        end

        ans = rule.op.match(self)

        m.move! ans, pos

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr.detected
          ans = grow_lr(rule, start_pos, m)
        end
      end

      if @log
        if ans
          puts "   OK #{rule.name} @ #{self.inspect}"
        else
          puts " FAIL #{rule.name} @ #{self.inspect}"
        end
      end
      return ans
    end

    def grow_lr(rule, start_pos, m)
      while true
        self.pos = start_pos
        ans = rule.op.match(self)
        return nil unless ans

        break if pos <= m.pos

        m.move! ans, pos
      end

      self.pos = m.pos
      return m.ans
    end

    def failed?
      !!@failing_op
    end

    def parse(name=nil)
      if name
        rule = @grammar.find(name)
        unless rule
          raise "Unknown rule - #{name}"
        end
      else
        rule = @grammar.root
      end

      match = apply rule

      if pos == string.size
        @failing_op = nil
      end

      return match
    end

    def expectation
      error_pos = @failing_offset
      line_no = current_line(error_pos)
      col_no = current_column(error_pos)

      expected = expected_string()

      prefix = nil

      case expected
      when String
        prefix = expected.inspect
      when Range
        prefix = "to be between #{expected.begin} and #{expected.end}"
      when Array
        prefix = "to be one of #{expected.inspect}"
      when nil
        prefix = "anything (no more input)"
      else
        prefix = "unknown"
      end

      return "Expected #{prefix} at line #{line_no}, column #{col_no} (offset #{error_pos})"
    end

  end


end
