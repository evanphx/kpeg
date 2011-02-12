module KPeg
  class Match; end

  class MatchString < Match
    def initialize(op, string)
      @op = op
      @string = string
    end

    attr_reader :op, :string

    def explain(indent="")
      puts "#{indent}KPeg::Match:#{object_id.to_s(16)}"
      puts "#{indent}  op: #{@op.inspect}"
      puts "#{indent}  string: #{@string.inspect}"
    end

    alias_method :total_string, :string

    def value(obj=nil)
      return @string unless @op.action
      if obj
        obj.instance_exec(@string, &@op.action)
      else
        @op.action.call(@string)
      end
    end
  end

  class MatchComposition < Match
    def initialize(op, matches)
      @op = op
      @matches = matches
    end

    attr_reader :op, :matches

    def explain(indent="")
      puts "#{indent}KPeg::Match:#{object_id.to_s(16)}"
      puts "#{indent}  op: #{@op.inspect}"
      puts "#{indent}  matches:"
      @matches.each do |m|
        m.explain("#{indent}    ")
      end
    end

    def total_string
      @matches.map { |m| m.total_string }.join
    end

    def value(obj=nil)
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
