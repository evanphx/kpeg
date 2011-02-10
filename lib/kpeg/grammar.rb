require 'strscan'

module KPeg
  class ParseFailure < RuntimeError; end

  class Parser < StringScanner
    def initialize(str, grammar, log=false)
      super str

      @grammar = grammar
      # A 2 level hash.
      @memoizations = Hash.new { |h,k| h[k] = {} }

      @failing_pos = nil
      @failing_op = nil
      @log = log
    end

    attr_reader :grammar, :memoizations
    attr_accessor :failing_op

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
      @failing_pos = pos
      @failing_op = op
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

    def error_expectation
      return "" unless @failing_op

      error_pos = @failing_pos
      line_no = current_line(error_pos)
      col_no = current_column(error_pos)

      return "Expected #{@failing_op.string.inspect} at line #{line_no}, column #{col_no} (offset #{error_pos})"
    end

    def show_error(io=STDOUT)
      return unless @failing_op

      error_pos = @failing_pos
      line_no = current_line(error_pos)
      col_no = current_column(error_pos)

      io.puts "Expected #{@failing_op.string.inspect} at line #{line_no}, column #{col_no} (offset #{error_pos})"
      io.puts "Got: #{string[error_pos,1].inspect}"
      io.puts "Operator: #{@failing_op.inspect}"
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
      ans = nil
      if m = @memoizations[rule][pos]
        m.inc!

        self.pos = m.pos
        if m.ans.kind_of? LeftRecursive
          m.ans.detected = true
          if @log
            puts "LR #{op.name} @ #{self.inspect}"
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
  end

  class Match
    def initialize(op, arg)
      @op = op
      if arg.kind_of? String
        @matches = nil
        @string = arg
      else
        @matches = arg
        @string = nil
      end
    end

    attr_reader :op, :string

    def matches
      return @matches if @matches
      return []
    end

    def explain(indent="")
      puts "#{indent}KPeg::Match:#{object_id.to_s(16)}"
      puts "#{indent}  op: #{@op.inspect}"
      if @string
        puts "#{indent}  string: #{@string.inspect}"
      else
        puts "#{indent}  matches:"
        @matches.each do |m|
          m.explain("#{indent}    ")
        end
      end
    end

    def total_string
      return @string if @string
      @matches.map { |m| m.total_string }.join
    end

    def value(obj=nil)
      if @string
        return @string unless @op.action
        if obj
          obj.instance_exec(@string, &@op.action)
        else
          @op.action.call(@string)
        end
      else
        values = @matches.map { |m| m.value(obj) }

        values = @op.prune_values(values)

        unless @op.action
          return values.first if values.size == 1
          return values
        end

        if obj
          obj.instance_exec(*values, &@op.action)
        else
          @op.action.call(*values)
        end
      end
    end
  end

  class Rule
    def initialize(name, op)
      @name = name
      @op = op
    end

    attr_reader :name, :op
  end

  class Operator
    def initialize
      @action = nil
      @has_tags = false
    end

    attr_accessor :action

    def set_action(act)
      @action = act
    end

    def detect_tags(ops)
      tags = []
      ops.each_with_index do |r,idx|
        if r.kind_of?(Tag)
          @has_tags = true
          tags << idx
        end
      end

      @tags = tags if @has_tags
    end

    def prune_values(values)
      return values unless @has_tags
      return values.values_at(*@tags)
    end

    def inspect_type(tag, body)
      "#<#{tag} #{body}>"
    end

    def |(other)
      Choice.new(self, Grammar.resolve(other))
    end
  end

  class Dot < Operator
    def match(x)
      if str = x.get_byte
        Match.new(self, str)
      else
        x.fail(self)
      end
    end

    def ==(obj)
      Dot === obj ? true : false
    end

    def inspect
      "#<dot>"
    end
  end

  class LiteralString < Operator
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

  class LiteralRegexp < Operator
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

  class CharRange < Operator
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

  class Choice < Operator
    def initialize(*many)
      super()
      @ops = many
    end

    attr_reader :ops

    def |(other)
      @ops << Grammar.resolve(other)
      self
    end

    def match(x)
      pos = x.pos

      @ops.each do |c|
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
        @ops == obj.ops
      else
        super
      end
    end

    def inspect
      inspect_type "any", @ops.map { |i| i.inspect }.join(' | ')
    end
  end

  class Multiple < Operator
    def initialize(op, min, max)
      super()
      @op = op
      @min = min
      @max = max
    end

    attr_reader :op, :min, :max

    def match(x)
      n = 0
      matches = []

      start = x.pos

      while true
        if m = @op.match(x)
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
        @op == obj.op and @min == obj.min and @max == obj.max
      else
        super
      end
    end

    def inspect
      inspect_type "multi", "#{@min} #{@max ? @max : "*"} #{@op.inspect}"
    end
  end

  class Sequence < Operator
    def initialize(*ops)
      super()
      @ops = ops
      detect_tags ops
    end

    attr_reader :ops

    def match(x)
      start = x.pos
      matches = @ops.map do |n|
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
        @ops == obj.ops
      else
        super
      end
    end

    def inspect
      inspect_type "seq", @ops.map { |i| i.inspect }.join(' ')
    end
  end

  class AndPredicate < Operator
    def initialize(op)
      super()
      @op = op
    end

    attr_reader :op

    def match(x)
      pos = x.pos
      m = @op.match(x)
      x.pos = pos

      return m ? Match.new(self, "") : nil
    end

    def ==(obj)
      case obj
      when AndPredicate
        @op == obj.op
      else
        super
      end
    end

    def inspect
      inspect_type "andp", @op.inspect
    end
  end

  class NotPredicate < Operator
    def initialize(op)
      super()
      @op = op
    end

    attr_reader :op

    def match(x)
      pos = x.pos
      m = @op.match(x)
      x.pos = pos

      return m ? nil : Match.new(self, "")
    end

    def ==(obj)
      case obj
      when NotPredicate
        @op == obj.op
      else
        super
      end
    end

    def inspect
      inspect_type "notp", @op.inspect
    end
  end

  class RuleReference < Operator
    def initialize(name, grammar=nil)
      super()
      @rule_name = name
      @grammar = grammar
    end

    attr_reader :rule_name

    def match(x)
      if @grammar and @grammar != x.grammar
        x.switch_grammar(@grammar) do
          rule = @grammar.find(@rule_name)
          raise "Unknown rule: '#{@rule_name}'" unless rule
          x.apply rule
        end
      else
        rule = x.grammar.find(@rule_name)
        raise "Unknown rule: '#{@rule_name}'" unless rule
        x.apply rule
      end
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

  class Tag < Operator
    def initialize(op, tag_name)
      super()
      @op = op
      @tag_name = tag_name
    end

    attr_reader :op, :tag_name

    def match(x)
      if m = @op.match(x)
        Match.new(self, [m])
      end
    end

    def ==(obj)
      case obj
      when Tag
        @op == obj.op and @tag_name == obj.tag_name
      when Operator
        @op == obj
      else
        super
      end
    end

    def inspect
      if @tag_name
        body = "@#{tag_name} "
      else
        body = ""
      end

      body << @op.inspect

      inspect_type "tag", body
    end
  end

  class Action < Operator
    def initialize(action)
      super()
      @action = action
    end

    attr_reader :action

    def match(x)
      return Match.new(self, "")
    end

    def ==(obj)
      case obj
      when Action
        @action == obj.action
      else
        super
      end
    end

    def inspect
      inspect_type "action", "=> #{action.inspect}"
    end
  end

  class Collect < Operator
    def initialize(op)
      super()
      @op = op
    end

    attr_reader :op

    def match(x)
      start = x.pos
      if @op.match(x)
        Match.new(self, x.string[start..x.pos])
      end
    end

    def ==(obj)
      case obj
      when Collect
        @op == obj.op
      else
        super
      end
    end

    def inspect
      inspect_type "collect", @op.inspect
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

    def set(name, op)
      if @rules.key? name
        raise "Already set rule named '#{name}'"
      end

      op = Grammar.resolve(op)

      @rule_order << name

      rule = Rule.new(name, op)
      @rules[name] = rule
    end

    def find(name)
      @rules[name]
    end

    def self.resolve(obj)
      case obj
      when Operator
        return obj
      when Symbol
        return RuleReference.new(obj.to_s)
      when String
        return LiteralString.new(obj)
      when Array
        ops = []
        obj.each do |x|
          case x
          when Sequence
            ops.concat x.ops
          when Operator
            ops << x
          else
            ops << resolve(x)
          end
        end

        return Sequence.new(*ops)
      when Range
        return CharRange.new(obj.begin.to_s, obj.end.to_s)
      when Regexp
        return LiteralRegexp.new(obj)
      else
        raise "Unknown obj type - #{obj.inspect}"
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
      op = Grammar.resolve(obj)
      op.set_action(b) if b
      op
    end

    def dot(&b)
      op = Dot.new
      op.set_action(b) if b
      op
    end

    def str(str, &b)
      op = LiteralString.new str
      op.set_action(b) if b
      op
    end

    def reg(reg, &b)
      op = LiteralRegexp.new reg
      op.set_action(b) if b
      op
    end

    def range(start, fin, &b)
      op = CharRange.new(start, fin)
      op.set_action(b) if b
      op
    end

    def any(*nodes, &b)
      nodes.map! { |x| Grammar.resolve(x) }
      op = Choice.new(*nodes)
      op.set_action(b) if b
      op
    end

    def multiple(node, min, max, &b)
      op = Multiple.new Grammar.resolve(node), min, max
      op.set_action(b) if b
      op
    end

    def maybe(node, &b)
      op = multiple Grammar.resolve(node), 0, 1, &b
    end

    def many(node, &b)
      multiple Grammar.resolve(node), 1, nil, &b
    end

    def kleene(node, &b)
      multiple Grammar.resolve(node), 0, nil, &b
    end

    def seq(*nodes, &b)
      ops = []
      nodes.each do |x|
        case x
        when Sequence
          ops.concat x.ops
        when Operator
          ops << x
        else
          ops << Grammar.resolve(x)
        end
      end

      op = Sequence.new(*ops)
      op.set_action(b) if b
      op
    end

    def andp(node)
      AndPredicate.new Grammar.resolve(node)
    end

    def notp(node)
      NotPredicate.new Grammar.resolve(node)
    end

    def ref(name, other_grammar=nil)
      RuleReference.new name.to_s, other_grammar
    end

    def t(op, name=nil)
      Tag.new Grammar.resolve(op), name
    end

    def action(action)
      Action.new action
    end

    def collect(op)
      Collect.new Grammar.resolve(op)
    end
  end


end
