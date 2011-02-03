require 'strscan'

module KPeg
  class ParseFailure < RuntimeError; end

  class Parser < StringScanner
    def initialize(str, grammar)
      super str

      @grammar = grammar
      # A 2 level hash.
      @memoizations = Hash.new { |h,k| h[k] = {} }

      @failing_pos = nil
      @failing_rule = nil
    end

    attr_reader :grammar, :memoizations
    attr_accessor :failing_rule

    def fail(rule)
      @failing_pos = pos
      @failing_rule = rule
      return nil
    end

    def current_column(target=pos)
      offset = 0
      string.each_line do |line|
        len = line.size
        return (target - offset) if offset + len >= target
        offset += len
      end

      -1
    end

    def current_line(target=pos)
      cur_offset = 0
      cur_line = 0

      string.each_line do |line|
        cur_line += 1
        cur_offset += line.size
        return cur_line if cur_offset >= target
      end

      -1
    end

    def lines
      lines = []
      string.each_line { |l| lines << l }
      lines
    end

    def show_error(io=STDOUT)
      return unless @failing_rule

      error_pos = @failing_pos
      line_no = current_line(error_pos)
      col_no = current_column(error_pos)

      io.puts "Expected #{@failing_rule.string.inspect} at line #{line_no}, column #{col_no} (offset #{error_pos})"
      io.puts "Got: #{string[error_pos,1].inspect}"
      io.puts "Rule: #{@failing_rule.inspect}"
      line = lines[line_no-1]
      io.puts "=> #{line}"
      io.print(" " * (col_no + 3))
      io.puts "^"
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

    def apply(rule)
      if m = @memoizations[rule][pos]
        m.inc!

        self.pos = m.pos
        if m.ans.kind_of? LeftRecursive
          m.ans.detected = true
          return nil
        end

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

    def failed?
      !!@failing_rule
    end

    def parse
      match = apply(@grammar.root)
      if pos == string.size
        @failing_rule = nil
      end

      return match
    end
  end

  class Match
    def initialize(rule, arg)
      @rule = rule
      if arg.kind_of? String
        @matches = nil
        @string = arg
      else
        @matches = arg
        @string = nil
      end
    end

    attr_reader :rule, :string

    def matches
      return @matches if @matches
      return []
    end

    def explain(indent="")
      puts "#{indent}KPeg::Match:#{object_id.to_s(16)}"
      puts "#{indent}  rule: #{@rule.inspect}"
      if @string
        puts "#{indent}  string: #{@string.inspect}"
      else
        puts "#{indent}  matches:"
        @matches.each do |m|
          m.explain("#{indent}    ")
        end
      end
    end

    def value(obj=nil)
      if @string
        return @string unless @rule.action
        if obj
          obj.instance_exec(@string, &@rule.action)
        else
          @rule.action.call(@string)
        end
      else
        values = @matches.map { |m| m.value(obj) }

        unless @rule.action
          return values.first if values.size == 1
          return values
        end

        if obj
          obj.instance_exec(*values, &@rule.action)
        else
          @rule.action.call(*values)
        end
      end
    end
  end

  class Rule
    def initialize
      @name = nil
      @action = nil
    end

    attr_accessor :name, :action

    def set_action(act)
      @action = act
    end

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
      else
        x.fail(self)
      end
    end

    def ==(obj)
      case obj
      when LiteralString
        @string == obj.string
      else
        super
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

    def string
      @regexp.source
    end

    def match(x)
      if str = x.scan(@regexp)
        Match.new(self, str)
      else
        x.fail(self)
      end
    end

    def ==(obj)
      case obj
      when LiteralRegexp
        @regexp == obj.regexp
      else
        super
      end
    end

    def inspect
      inspect_type 'reg', @regexp.inspect
    end
  end

  class CharRange < Rule
    def initialize(start, fin)
      super()
      @start = start
      @fin = fin
      @regexp = Regexp.new "[#{Regexp.quote start}-#{Regexp.quote fin}]"
    end

    attr_reader :start, :fin

    def string
      @regexp.source
    end

    def match(x)
      if str = x.scan(@regexp)
        Match.new(self, str)
      else
        x.fail(self)
      end
    end

    def ==(obj)
      case obj
      when CharRange
        @start == obj.start and @fin == obj.fin
      else
        super
      end
    end

    def inspect
      inspect_type 'range', "#{@start}-#{@fin}"
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
      pos = x.pos

      @rules.each do |c|
        if m = c.match(x)
          return m
        end

        x.pos = pos
      end

      return nil
    end

    def ==(obj)
      case obj
      when Choice
        @rules == obj.rules
      else
        super
      end
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

      start = x.pos

      while true
        if m = @rule.match(x)
          matches << m
        else
          break
        end

        n += 1

        if @max and n > @max
          x.pos = start
          return nil
        end
      end

      if n >= @min
        return Match.new(self, matches)
      end

      x.pos = start
      return nil
    end

    def ==(obj)
      case obj
      when Multiple
        @rule == obj.rule and @min == obj.min and @max == obj.max
      else
        super
      end
    end

    def inspect
      inspect_type "multi", "#{@min} #{@max ? @max : "*"} #{@rule.inspect}"
    end
  end

  class Sequence < Rule
    def initialize(*rules)
      super()
      @rules = rules
    end

    attr_reader :rules

    def match(x)
      start = x.pos
      matches = @rules.map do |n|
        m = n.match(x)
        unless m
          x.pos = start
          return nil
        end
        m
      end
      Match.new(self, matches)
    end

    def ==(obj)
      case obj
      when Sequence
        @rules == obj.rules
      else
        super
      end
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

    def ==(obj)
      case obj
      when AndPredicate
        @rule == obj.rule
      else
        super
      end
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

    def ==(obj)
      case obj
      when NotPredicate
        @rule == obj.rule
      else
        super
      end
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

    def ==(obj)
      case obj
      when RuleReference
        @rule_name == obj.rule_name
      else
        super
      end
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

      rule = Grammar.resolve(rule)

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
      when Range
        return CharRange.new(rule.begin.to_s, rule.end.to_s)
      when Regexp
        return LiteralRegexp.new(rule)
      else
        raise "Unknown rule type - #{rule.inspect}"
      end
    end

    # Use these to access the rules unambigiously
    def [](rule)
      ref(rule.to_s)
    end

    def []=(name, rule)
      set(name, rule)
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

    def lit(obj, &b)
      rule = Grammar.resolve(obj)
      rule.set_action(b) if b
      rule
    end

    def str(str, &b)
      rule = LiteralString.new str
      rule.set_action(b) if b
      rule
    end

    def reg(reg, &b)
      rule = LiteralRegexp.new reg
      rule.set_action(b) if b
      rule
    end

    def range(start, fin, &b)
      rule = CharRange.new(start, fin)
      rule.set_action(b) if b
      rule
    end

    def any(*nodes, &b)
      nodes.map! { |x| Grammar.resolve(x) }
      rule = Choice.new(*nodes)
      rule.set_action(b) if b
      rule
    end

    def multiple(node, min, max, &b)
      rule = Multiple.new Grammar.resolve(node), min, max
      rule.set_action(b) if b
      rule
    end

    def maybe(node, &b)
      rule = multiple Grammar.resolve(node), 0, 1, &b
    end

    def many(node, &b)
      multiple Grammar.resolve(node), 1, nil, &b
    end

    def kleene(node, &b)
      multiple Grammar.resolve(node), 0, nil, &b
    end

    def seq(*nodes, &b)
      nodes.map! { |x| Grammar.resolve(x) }
      rule = Sequence.new(*nodes)
      rule.set_action(b) if b
      rule
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

    def parens?(rule)
      case rule
      when Sequence, Multiple, AndPredicate, NotPredicate
        return true
      end

      false
    end

    def render_rule(io, rule)
      case rule
      when LiteralString
        subd = rule.string.gsub(/[\n]/, '\n')
        if subd.index('"')
          io.print "'"
          io.print subd
          io.print "'"
        else
          io.print '"'
          io.print subd
          io.print '"'
        end
      when LiteralRegexp
        io.print rule.regexp.inspect
      when CharRange
        io.print "[#{rule.start}-#{rule.fin}]"
      when Sequence
        rule.rules.each_with_index do |r,idx|
          unless idx == 0
            io.print " "
          end
          render_rule io, r
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
        if parens?(rule.rule)
          io.print "("
          render_rule io, rule.rule
          io.print ")"
        else
          render_rule io, rule.rule
        end

        if rule.max
          if rule.min == 0 and rule.max == 1
            io.print "?"
          else
            io.print "[#{rule.min}, #{rule.max}]"
          end
        elsif rule.min == 0
          io.print "*"
        elsif rule.min == 1
          io.print "+"
        else
          io.print "[>=#{rule.min}]"
        end
      when AndPredicate
        io.print "&"
        if parens?(rule.rule)
          io.print "("
          render_rule io, rule.rule
          io.print ")"
        else
          render_rule io, rule.rule
        end
      when NotPredicate
        io.print "!"
        if parens?(rule.rule)
          io.print "("
          render_rule io, rule.rule
          io.print ")"
        else
          render_rule io, rule.rule
        end
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
    scan.parse
  end

      # g.pattern     = g.alternative + (pattern("/") + g.sp + g.alternative) * 0
      # g.alternative = ((+g.predicate + g.predicate + g.sp + g.suffix) /
                      # (g.sp + g.suffix)) * 1
      # g.predicate   = ["!&"]
      # g.suffix      = g.primary + (pattern(["*+?"]) + g.sp) * 0
      # g.primary     = (pattern("(") + g.sp + g.pattern + ")" + g.sp) / (pattern(1) + g.sp) /
                      # g.literal / g.char_class / (g.nonterminal + -pattern("="))
      # g.literal     = pattern("'") + (-pattern("'") + 1) * 0 + "'" + g.sp
      # g.char_class  = (pattern("[") + (-pattern("]") +
                      # ((pattern(1) + "-" + 1) / 1)) * 0) + "]" + g.sp
      # g.nonterminal = (pattern("_") / ["a".."z"] / ["A".."Z"]) * 1 + g.sp
      # g.sp          = pattern([" \t\n"]) * 0


  # NativeFormat = KPeg.grammar do |g|

    # g.root = g.many :assigment
    # g.assignment = [:var, "=", :spaces, :choice]
    # g.choice = [:sequence, g.kleene("|", :spaces, :sequence)]
    # g.sequence = [g.notp(:predicate), :predicate 

     # g.space = /[\s\t\n]/
    # g.spaces = g.many(:space)
       # g.var = /[a-zA-Z][a-zA-Z0-9]*/
     # g.alnum = /[a-zA-Z0-9/
      # g.make = [:var, :spaces, "=", :spaces, :expr]

    # g.string = /"[^"]*"/
    # g.non_slash = g.any("\/", %r![^/]!)
    # g.regexp = ["/", :non_slash, "/"]
    # g.char_range = ["[", :alnum, '-', :alnum, "]"]

    # g.sequence = g.many :multiple
    # g.multiple
    # g.pick_any  = [:expr, "*"]
    # g.maybe_one = [:expr, "?"]
    # g.one_plus =  [:expr, "+"]

    # g.expr = g.string | g.regexp | g.sequence | g.choice | g.pick_any \
           # | g.maybe_one | g.one_plus
end
