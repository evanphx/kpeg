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

        op = rule.op

        if op.kind_of? Choice
          op.ops.each_with_index do |r,idx|
            unless idx == 0
              io.print "\n#{' ' * (indent+1)}| "
            end

            render_op io, r
          end
        else
          render_op io, op
        end

        io.puts
      end
    end

    def parens?(op)
      case op
      when Sequence, AndPredicate, NotPredicate
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

    def render_op(io, op)
      case op
      when Dot
        io.print "."
      when LiteralString
        esc = GrammarRenderer.escape op.string
        io.print '"'
        io.print esc
        io.print '"'
      when LiteralRegexp
        io.print op.regexp.inspect
      when CharRange
        io.print "[#{op.start}-#{op.fin}]"
      when Sequence
        op.ops.each_with_index do |r,idx|
          unless idx == 0
            io.print " "
          end
          render_op io, r
        end
      when Choice
        io.print "("
        op.ops.each_with_index do |r,idx|
          unless idx == 0
            io.print " | "
          end

          render_op io, r
        end
        io.print ")"
      when Multiple
        if parens?(op.op)
          io.print "("
          render_op io, op.op
          io.print ")"
        else
          render_op io, op.op
        end

        if op.max
          if op.min == 0 and op.max == 1
            io.print "?"
          else
            io.print "[#{op.min}, #{op.max}]"
          end
        elsif op.min == 0
          io.print "*"
        elsif op.min == 1
          io.print "+"
        else
          io.print "[#{op.min},*]"
        end
      when AndPredicate
        io.print "&"
        if parens?(op.op)
          io.print "("
          render_op io, op.op
          io.print ")"
        else
          render_op io, op.op
        end
      when NotPredicate
        io.print "!"
        if parens?(op.op)
          io.print "("
          render_op io, op.op
          io.print ")"
        else
          render_op io, op.op
        end
      when RuleReference
        io.print op.rule_name
      when Tag
        if parens?(op.op)
          io.print "("
          render_op io, op.op
          io.print ")"
        else
          render_op io, op.op
        end

        if op.tag_name
          io.print ":#{op.tag_name}"
        end
      when Action
        io.print "{#{op.action}}"
      when Collect
        io.print "< "
        render_op io, op.op
        io.print " >"
      else
        raise "Unknown op type - #{op.class}"
      end
    end
  end

end
