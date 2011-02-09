module KPeg
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

    StringEscape = KPeg.grammar do |g|
      g.escapes = g.str("\\") { "\\\\" } \
                | g.str("\n") { "\\n" }  \
                | g.str("\t") { "\\t" }  \
                | g.str("\b") { "\\b" }  \
                | g.str('"')  { "\\\"" }
      g.root = g.many(g.any(:escapes, g.dot))
    end

    def self.escape(str)
      m = KPeg.match str, StringEscape
      val = m.value
      val = val.join if val.kind_of?(Array)
      val
    end

    def render_rule(io, rule)
      case rule
      when Dot
        io.print "."
      when LiteralString
        esc = GrammarRenderer.escape rule.string
        io.print '"'
        io.print esc
        io.print '"'
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
          io.print "[#{rule.min},*]"
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
      when Tag
        if parens?(rule.rule)
          io.print "("
          render_rule io, rule.rule
          io.print ")"
        else
          render_rule io, rule.rule
        end

        if rule.tag_name
          io.print ":#{rule.tag_name}"
        end
      when Action
        io.print "{#{rule.action}}"
      when Collect
        io.print "< "
        render_rule io, rule.rule
        io.print " >"
      else
        raise "Unknown rule type - #{rule.class}"
      end
    end
  end

end
