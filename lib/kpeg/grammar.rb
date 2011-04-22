require 'strscan'
require 'kpeg/parser'
require 'kpeg/match'

module KPeg
  class Rule
    def initialize(name, op, args=nil)
      @name = name
      @op = op
      @arguments = args
    end

    attr_reader :name, :op, :arguments
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
        MatchString.new(self, str)
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
        MatchString.new(self, str)
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
    def initialize(reg, opts=nil)
      super()

      if reg.kind_of? String
        flags = 0
        lang = nil

        if opts
          opts.split("").each do |o|
            case o
            when "n", "N", "e", "E", "s", "S"
              lang = o.downcase
            when "u", "U"
              if RUBY_VERSION > "1.8.7"
                # Ruby 1.9 defaults to UTF-8 for string matching
                lang = ""
              else
                lang = "u"
              end
            when "m"
              flags |= Regexp::MULTILINE
            when "x"
              flags |= Regexp::EXTENDED
            when "i"
              flags |= Regexp::IGNORECASE
            end
          end
        end

        @regexp = Regexp.new(reg, flags, lang)
      else
        @regexp = reg
      end
    end

    attr_reader :regexp

    def string
      @regexp.source
    end

    def match(x)
      if str = x.scan(@regexp)
        MatchString.new(self, str)
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
        MatchString.new(self, str)
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
      @save_values = nil
    end

    attr_reader :op, :min, :max, :save_values

    def save_values!
      @save_values = true
    end

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
        return MatchComposition.new(self, matches)
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
      MatchComposition.new(self, matches)
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

      return m ? MatchString.new(self, "") : nil
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

      return m ? nil : MatchString.new(self, "")
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

  class InvokeRule < Operator
    def initialize(name, args=nil)
      super()
      @rule_name = name
      @arguments = args
    end

    attr_reader :rule_name, :arguments

    def match(x)
      rule = x.grammar.find(@rule_name)
      raise "Unknown rule: '#{@rule_name}'" unless rule
      x.invoke rule
    end

    def ==(obj)
      case obj
      when InvokeRule
        @rule_name == obj.rule_name and @arguments == obj.arguments
      else
        super
      end
    end

    def inspect
      if @arguments
        body = "#{@rule_name} #{@arguments}"
      else
        body = @rule_name
      end
      inspect_type "invoke", body
    end
  end

  class ForeignInvokeRule < Operator
    def initialize(grammar, name, args=nil)
      super()
      @grammar_name = grammar
      @rule_name = name
      if !args or args.empty?
        @arguments = nil
      else
        @arguments = args
      end
    end

    attr_reader :grammar_name, :rule_name, :arguments

    def match(x)
      rule = x.grammar.find(@rule_name)
      raise "Unknown rule: '#{@rule_name}'" unless rule
      x.invoke rule
    end

    def ==(obj)
      case obj
      when ForeignInvokeRule
        @grammar_name == obj.grammar_name and \
          @rule_name == obj.rule_name and @arguments == obj.arguments
      else
        super
      end
    end

    def inspect
      if @arguments
        body = "%#{@grammar}.#{@rule_name} #{@arguments}"
      else
        body = "%#{@grammar}.#{@rule_name}"
      end
      inspect_type "invoke", body
    end
  end

  class Tag < Operator
    def initialize(op, tag_name)
      super()
      if op.kind_of? Multiple
        op.save_values!
      end

      @op = op
      @tag_name = tag_name
    end

    attr_reader :op, :tag_name

    def match(x)
      if m = @op.match(x)
        MatchComposition.new(self, [m])
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
      return MatchString.new(self, "")
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
        MatchString.new(self, x.string[start..x.pos])
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

  class Bounds < Operator
    def initialize(op)
      super()
      @op = op
    end

    attr_reader :op

    def ==(obj)
      case obj
      when Bounds
        @op == obj.op
      else
        super
      end
    end

    def inspect
      inspect_type "bounds", @op.inspect
    end
  end

  class Grammar
    def initialize
      @rules = {}
      @rule_order = []
      @setup_actions = []
      @foreign_grammars = {}
      @variables = {}
    end

    attr_reader :rules, :rule_order, :setup_actions, :foreign_grammars
    attr_reader :variables

    def add_setup(act)
      @setup_actions << act
    end

    def add_foreign_grammar(name, str)
      @foreign_grammars[name] = str
    end

    def set_variable(name, val)
      @variables[name] = val
    end

    def root
      @rules["root"]
    end

    def set(name, op, args=nil)
      if @rules.key? name
        raise "Already set rule named '#{name}'"
      end

      op = Grammar.resolve(op)

      @rule_order << name

      rule = Rule.new(name, op, args)
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
      elsif !args.empty?
        super
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

    def reg(reg, opts=nil, &b)
      op = LiteralRegexp.new reg, opts
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

    def invoke(name, args=nil)
      InvokeRule.new name.to_s, args
    end

    # Invoke a rule defined on a foreign grammar
    # == Parameters:
    # gram::
    #   The name of the grammar that the rule will be reference from 
    # name::
    #   The name of the rule that will be invoked
    # args::
    #   Any arguements that should be passed to the rule
    # == Returns:
    #   A new ForeignInvokeRule
    def foreign_invoke(gram, name, args=nil)
      ForeignInvokeRule.new gram, name.to_s, args
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

    def bounds(op)
      Bounds.new Grammar.resolve(op)
    end
  end


end
