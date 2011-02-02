require 'strscan'

module KPeg
  class ParseFailure < RuntimeError; end

  class Parser < StringScanner
    def initialize(str, grammar)
      super str

      @grammar = grammar
      # A 2 level hash.
      @memoizations = Hash.new { |h,k| h[k] = {} }
    end

    attr_reader :grammar, :memoizations

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
          return nil
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

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr.detected
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
        ans = rule.match(self)
        return nil unless ans

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

    def |(other)
      Choice.new(self, Grammar.resolve(other))
    end
  end

  class LiteralString < Rule
    def initialize(str)
      super()
      @string = str
      @reg = Regexp.new Regexp.quote(str)
    end

    attr_reader :string

    def match(x)
      if str = x.scan(@reg)
        Match.new(self, str)
      end
    end

    def inspect
      inspect_type 'str', @string.inspect
    end
  end

  class LiteralRegexp < Rule
    def initialize(reg)
      super()
      @regexp = reg
    end

    attr_reader :regexp

    def match(x)
      if str = x.scan(@regexp)
        Match.new(self, str)
      end
    end

    def inspect
      inspect_type 'reg', @regexp.inspect
    end
  end

  class Choice < Rule
    def initialize(*many)
      super()
      @rules = many
    end

    attr_reader :rules

    def |(other)
      @rules << Grammar.resolve(other)
      self
    end

    def match(x)
      @rules.each do |c|
        pos = x.pos

        if m = c.match(x)
          return m
        end

        x.pos = pos
      end

      return nil
    end

    def inspect
      inspect_type "any", @rules.map { |i| i.inspect }.join(' | ')
    end
  end

  class Multiple < Rule
    def initialize(rule, min, max)
      super()
      @rule = rule
      @min = min
      @max = max
    end

    attr_reader :rule, :min, :max

    def match(x)
      n = 0
      matches = []

      while true
        if m = @rule.match(x)
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

      return nil
    end
  end

  class Sequence < Rule
    def initialize(*rules)
      super()
      @rules = rules
    end

    attr_reader :rules

    def match(x)
      matches = @rules.map do |n|
        m = n.match(x)
        return nil unless m
        m
      end
      Match.new(self, matches)
    end

    def inspect
      inspect_type "seq", @rules.map { |i| i.inspect }.join(' ')
    end
  end

  class AndPredicate < Rule
    def initialize(rule)
      super()
      @rule = rule
    end

    attr_reader :rule

    def match(x)
      pos = x.pos
      m = @rule.match(x)
      x.pos = pos

      return m ? Match.new(self, "") : nil
    end

    def inspect
      inspect_type "andp", @rule.inspect
    end
  end

  class NotPredicate < Rule
    def initialize(rule)
      super()
      @rule = rule
    end

    attr_reader :rule

    def match(x)
      pos = x.pos
      m = @rule.match(x)
      x.pos = pos

      return m ? nil : Match.new(self, "")
    end

    def inspect
      inspect_type "notp", @rule.inspect
    end
  end

  class RuleReference < Rule
    def initialize(name)
      super()
      @rule_name = name
    end

    attr_reader :rule_name

    def resolve(x)
      rule = x.grammar.find(@rule_name)
      raise "Unknown rule: '#{@rule_name}'" unless rule
      rule
    end

    def match(x)
      x.apply resolve(x)
    end

    def inspect
      inspect_type "ref", @rule_name
    end
  end

  class Grammar
    def initialize
      @rules = {}
      @rule_order = []
    end

    attr_reader :rules, :rule_order

    def root
      @rules["root"]
    end

    def set(name, rule)
      if @rules.key? name
        raise "Already set rule named '#{name}'"
      end

      @rule_order << name
      rule.name = name

      @rules[name] = rule
    end

    def find(name)
      @rules[name]
    end

    def self.resolve(rule)
      case rule
      when Rule
        return rule
      when Symbol
        return RuleReference.new(rule.to_s)
      when String
        return LiteralString.new(rule)
      when Array
        rules = rule.map { |x| resolve(x) }
        return Sequence.new(*rules)
      else
        raise "Unknown rule type - #{rule.inspect}"
      end
    end

    def method_missing(meth, *args)
      meth_s = meth.to_s

      if meth_s[-1,1] == "="
        rule = args.first
        set(meth_s[0..-2], rule)
        return rule
      end

      # Hm, I guess this is fine. It might end up confusing people though.
      return ref(meth.to_s)
    end

    def str(str)
      LiteralString.new str
    end

    def reg(reg)
      LiteralRegexp.new reg
    end

    def any(*nodes)
      nodes.map! { |x| Grammar.resolve(x) }
      Choice.new(*nodes)
    end

    def multiple(node, min, max)
      Multiple.new Grammar.resolve(node), min, max
    end

    def maybe(node)
      multiple Grammar.resolve(node), 0, 1
    end

    def many(node)
      multiple Grammar.resolve(node), 1, nil
    end

    def kleene(node)
      multiple Grammar.resolve(node), 0, nil
    end

    def seq(*nodes)
      nodes.map! { |x| Grammar.resolve(x) }
      Sequence.new(*nodes)
    end

    def andp(node)
      AndPredicate.new Grammar.resolve(node)
    end

    def notp(node)
      NotPredicate.new Grammar.resolve(node)
    end

    def ref(name)
      RuleReference.new name.to_s
    end
  end

  class GrammarRenderer
    def initialize(gram)
      @grammar = gram
    end

    def render(io)
      widest = @grammar.rules.keys.sort { |a,b| a.size <=> b.size }.last
      indent = widest.size

      @grammar.rule_order.each do |name|
        rule = @grammar.find(name)

        io.print(' ' * (indent - name.size))
        io.print "#{name} = "

        if rule.kind_of? Choice
          rule.rules.each_with_index do |r,idx|
            unless idx == 0
              io.print "\n#{' ' * (indent+1)}| "
            end

            render_rule io, r
          end
        else
          render_rule io, rule
        end

        io.puts
      end
    end

    def render_rule(io, rule)
      case rule
      when LiteralString
        io.print rule.string.inspect
      when LiteralRegexp
        io.print rule.regexp.inspect
      when Sequence
        rule.rules.each do |r|
          render_rule io, r
          io.print " "
        end
      when Choice
        io.print "("
        rule.rules.each_with_index do |r,idx|
          unless idx == 0
            io.print " | "
          end

          render_rule io, r
        end
        io.print ")"
      when Multiple
        render_rule io, rule.rule
        io.print "[#{rule.min}, #{rule.max}]"
      when AndPredicate
        io.print "&"
        render_rule io, rule.rule
      when NotPredicate
        io.print "!"
        render_rule io, rule.rule
      when RuleReference
        io.print rule.rule_name
      end
    end
  end

  def self.grammar
    g = Grammar.new
    yield g
    g
  end

  def self.match(str, gram)
    scan = Parser.new(str, gram)
    scan.apply(gram.root)
  end
end
