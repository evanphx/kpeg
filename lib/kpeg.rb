require 'strscan'

module KPeg
  class Parser < StringScanner
    def initialize(str)
      super str
      # A 2 level hash.
      @memoizations = Hash.new { |h,k| h[k] = {} }
    end

    attr_reader :memoizations

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

      def fail?
        @ans.nil?
      end
    end

    def apply(rule)
      if m = @memoizations[rule][pos]
        m.inc!
        self.pos = m.pos
        return m.ans
      else
        m = MemoEntry.new(nil, pos)
        @memoizations[rule][pos] = m

        ans = rule.match(self)

        m.move! ans, pos

        return ans
      end
    end
  end

  class Match
    def initialize(node, arg)
      @node = node
      if arg.kind_of? String
        @matches = nil
        @string = arg
      else
        @matches = arg
        @string = nil
      end
    end

    attr_reader :node, :string

    def matches
      return @matches if @matches
      return []
    end
  end

  class LiteralString
    def initialize(str)
      @str = Regexp.new Regexp.quote(str)
    end

    def match(x)
      if str = x.scan(@str)
        Match.new(self, str)
      end
    end
  end

  class LiteralRegexp
    def initialize(reg)
      @reg = reg
    end

    def match(x)
      if str = x.scan(@reg)
        Match.new(self, str)
      end
    end
  end

  class Choice
    def initialize(*many)
      @choices = many
    end

    def match(x)
      @choices.each do |c|
        pos = x.pos

        if m = x.apply(c)
          return m
        end

        x.pos = pos
      end

      return nil
    end
  end

  class Multiple
    def initialize(node, min, max)
      @node = node
      @min = min
      @max = max
    end

    def match(x)
      n = 0
      matches = []

      while true
        if m = x.apply(@node)
          matches << m
        else
          break
        end

        n += 1

        return nil if @max and n > @max
      end

      if n >= @min
        return Match.new(self, matches)
      end
    end
  end

  class Sequence
    def initialize(*nodes)
      @nodes = nodes
    end

    def match(x)
      matches = @nodes.map do |n|
        if m = x.apply(n)
          m
        else
          return nil
        end
      end

      Match.new(self, matches)
    end
  end

  class AndPredicate
    def initialize(node)
      @node = node
    end

    def match(x)
      pos = x.pos
      matched = x.apply(@node)
      x.pos = pos
      return matched ? Match.new(self, "") : nil
    end
  end

  class NotPredicate
    def initialize(node)
      @node = node
    end

    def match(x)
      pos = x.pos
      matched = x.apply(@node)
      x.pos = pos

      return matched ? nil : Match.new(self, "")
    end
  end

  class RuleReference
    def initialize(layout, name)
      @layout = layout
      @name = name
    end

    def match(x)
      rule = @layout.find(@name)
      raise "Unknown rule: '#{@name}'" unless rule
      x.apply(rule)
    end
  end

  class Layout
    def initialize
      @rules = {}
    end

    def set(name, rule)
      if @rules.key? name
        raise "Already set rule named '#{name}'"
      end

      @rules[name] = rule
    end

    def find(name)
      @rules[name]
    end

    def method_missing(meth, *args)
      meth_s = meth.to_s

      if meth_s[-1,1] == "="
        rule = args.first
        set(meth_s[0..-2], rule)
        return rule
      elsif rule = @rules[meth_s]
        return rule
      end

      super
    end

    def str(str)
      LiteralString.new(str)
    end

    def reg(reg)
      LiteralRegexp.new(reg)
    end

    def any(*nodes)
      Choice.new(*nodes)
    end

    def multiple(node, min, max)
      Multiple.new(node, min, max)
    end

    def maybe(node)
      multiple(node, 0, 1)
    end

    def many(node)
      multiple(node, 1, nil)
    end

    def kleene(node)
      multiple(node, 0, nil)
    end

    def seq(*nodes)
      Sequence.new(*nodes)
    end

    def andp(node)
      AndPredicate.new(node)
    end

    def notp(node)
      NotPredicate.new(node)
    end

    def ref(name)
      RuleReference.new(self, name.to_s)
    end
  end

  def self.layout
    l = Layout.new
    yield l
  end

  def self.match(str, node)
    scan = Parser.new(str)
    scan.apply(node)
  end
end
