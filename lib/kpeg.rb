require 'strscan'

module KPeg
  class ParseFailure < RuntimeError; end

  class Parser < StringScanner
    def initialize(str)
      super str
      # A 2 level hash.
      @memoizations = Hash.new { |h,k| h[k] = {} }
    end

    attr_reader :memoizations

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

    def apply(rule)
      if m = @memoizations[rule][pos]
        m.inc!

        if m.ans.kind_of? LeftRecursive
          m.ans.detected = true
          raise ParseFailure
        end

        self.pos = m.pos
        return m.ans
      else
        lr = LeftRecursive.new(false)
        m = MemoEntry.new(lr, pos)
        @memoizations[rule][pos] = m
        start_pos = pos

        ans = rule.match(self)

        m.move! ans, pos

        if lr.detected
          return grow_lr(rule, start_pos, m)
        else
          return ans
        end

        return ans
      end
    end

    def grow_lr(rule, start_pos, m)
      while true
        self.pos = start_pos
        begin
          ans = rule.match(self)
        rescue ParseFailure
          break
        end

        break if pos <= m.pos

        m.move! ans, pos
      end

      self.pos = m.pos
      return m.ans
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

    def explain(indent="")
      puts "#{indent}KPeg::Match:#{object_id.to_s(16)}"
      puts "#{indent}  node: #{@node.inspect}"
      if @string
        puts "#{indent}  string: #{@string.inspect}"
      else
        puts "#{indent}  matches:"
        @matches.each do |m|
          m.explain("#{indent}    ")
        end
      end
    end
  end

  class Rule
    def initialize
      @name = nil
    end

    attr_accessor :name

    def inspect_type(tag, body)
      return "#<#{tag} #{body}>" unless @name
      "#<#{tag}:#{@name} #{body}>"
    end
  end

  class LiteralString < Rule
    def initialize(str)
      super()
      @string = str
      @reg = Regexp.new Regexp.quote(str)
    end

    def match(x)
      if str = x.scan(@reg)
        Match.new(self, str)
      else
        raise ParseFailure
      end
    end

    def inspect
      inspect_type 'str', @string.inspect
    end
  end

  class LiteralRegexp < Rule
    def initialize(reg)
      super()
      @reg = reg
    end

    def match(x)
      if str = x.scan(@reg)
        Match.new(self, str)
      else
        raise ParseFailure
      end
    end

    def inspect
      inspect_type 'reg', @reg.inspect
    end
  end

  class Choice < Rule
    def initialize(*many)
      super()
      @choices = many
    end

    def match(x)
      @choices.each do |c|
        pos = x.pos

        begin
          return c.match(x)
        rescue ParseFailure
        end

        x.pos = pos
      end

      raise ParseFailure
    end

    def inspect
      inspect_type "any", @choices.map { |i| i.inspect }.join(' | ')
    end
  end

  class Multiple < Rule
    def initialize(node, min, max)
      super()
      @node = node
      @min = min
      @max = max
    end

    def match(x)
      n = 0
      matches = []

      while true
        begin
          matches << @node.match(x)
        rescue ParseFailure
          break
        end

        n += 1

        return nil if @max and n > @max
      end

      if n >= @min
        return Match.new(self, matches)
      end

      raise ParseFailure
    end
  end

  class Sequence < Rule
    def initialize(*nodes)
      super()
      @nodes = nodes
    end

    def match(x)
      matches = @nodes.map { |n| n.match(x) }
      Match.new(self, matches)
    end

    def inspect
      inspect_type "seq", @nodes.map { |i| i.inspect }.join(' ')
    end
  end

  class AndPredicate < Rule
    def initialize(node)
      super()
      @node = node
    end

    def match(x)
      pos = x.pos

      begin
        @node.match(x)
      ensure
        x.pos = pos
      end

      return Match.new(self, "")
    end

    def inspect
      inspect_type "andp", @node.inspect
    end
  end

  class NotPredicate < Rule
    def initialize(node)
      super()
      @node = node
    end

    def match(x)
      pos = x.pos

      begin
        @node.match(x)
        matched = true
      rescue ParseFailure
        matched = false
      ensure
        x.pos = pos
      end

      return matched ? nil : Match.new(self, "")
    end

    def inspect
      inspect_type "notp", @node.inspect
    end
  end

  class RuleReference < Rule
    def initialize(layout, name)
      super()
      @layout = layout
      @rule_name = name
    end

    def resolve
      rule = @layout.find(@rule_name)
      raise "Unknown rule: '#{@name}'" unless rule
      rule
    end

    def match(x)
      x.apply(resolve)
    end

    def inspect
      inspect_type "ref", @rule_name
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

      rule.name = name

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

    begin
      m = scan.apply(node)
    rescue ParseFailure
      m = nil
    end

    return m
  end
end
