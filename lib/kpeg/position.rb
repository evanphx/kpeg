module KPeg
  module Position
    # STANDALONE START

    def current_column(target=pos)
      if c = string.rindex("\n", target-1)
        return target - c - 1
      end

      target + 1
    end

    def current_line(target=pos)
      unless @line_offsets
        @line_offsets = [-1]
        total = 0
        string.each_line do |line|
          @line_offsets << total
          total += line.size
        end
        @line_offsets << total
      end

      @line_offsets.bsearch_index {|x| x >= target } || -1
    end

    def lines
      lines = []
      string.each_line { |l| lines << l }
      lines
    end

    # STANDALONE END

  end
end
