class Upper
  # :stopdoc:

    # This is distinct from setup_parser so that a standalone parser
    # can redefine #initialize and still have access to the proper
    # parser setup code.
    def initialize(str, debug=false)
      setup_parser(str, debug)
    end



    # Prepares for parsing +str+.  If you define a custom initialize you must
    # call this method before #parse
    def setup_parser(str, debug=false)
      set_string str, 0
      @memoizations = Hash.new { |h,k| h[k] = {} }
      @result = nil
      @failed_rule = nil
      @failing_rule_offset = -1
      @line_offsets = nil

      setup_foreign_grammar
    end

    attr_reader :string
    attr_reader :failing_rule_offset
    attr_accessor :result, :pos

    def current_column(target=pos)
      if string[target] == "\n" && (c = string.rindex("\n", target-1) || -1)
        return target - c
      elsif c = string.rindex("\n", target)
        return target - c
      end

      target + 1
    end

    def position_line_offsets
      unless @position_line_offsets
        @position_line_offsets = []
        total = 0
        string.each_line do |line|
          total += line.size
          @position_line_offsets << total
        end
      end
      @position_line_offsets
    end

    if [].respond_to? :bsearch_index
      def current_line(target=pos)
        if line = position_line_offsets.bsearch_index {|x| x > target }
          return line + 1
        elsif target == string.size
          past_last = !string.empty? && string[-1]=="\n" ? 1 : 0
          return position_line_offsets.size + past_last
        end
        raise "Target position #{target} is outside of string"
      end
    else
      def current_line(target=pos)
        if line = position_line_offsets.index {|x| x > target }
          return line + 1
        elsif target == string.size
          past_last = !string.empty? && string[-1]=="\n" ? 1 : 0
          return position_line_offsets.size + past_last
        end
        raise "Target position #{target} is outside of string"
      end
    end

    def current_character(target=pos)
      if target < 0 || target > string.size
        raise "Target position #{target} is outside of string"
      elsif target == string.size
        ""
      else
        string[target, 1]
      end
    end

    KpegPosInfo = Struct.new(:pos, :lno, :col, :line, :char)

    def current_pos_info(target=pos)
      l = current_line target
      c = current_column target
      ln = get_line(l-1)
      chr = string[target,1]
      KpegPosInfo.new(target, l, c, ln, chr)
    end

    def lines
      string.lines
    end

    def get_line(no)
      loff = position_line_offsets
      if no < 0
        raise "Line No is out of range: #{no} < 0"
      elsif no >= loff.size
        raise "Line No is out of range: #{no} >= #{loff.size}"
      end
      lend = loff[no]-1
      lstart = no > 0 ? loff[no-1] : 0
      string[lstart..lend]
    end



    def get_text(start)
      @string[start..@pos-1]
    end

    # Sets the string and current parsing position for the parser.
    def set_string string, pos
      @string = string
      @string_size = string ? string.size : 0
      @pos = pos
      @position_line_offsets = nil
    end

    def show_pos
      width = 10
      if @pos < width
        "#{@pos} (\"#{@string[0,@pos]}\" @ \"#{@string[@pos,width]}\")"
      else
        "#{@pos} (\"... #{@string[@pos - width, width]}\" @ \"#{@string[@pos,width]}\")"
      end
    end

    def failure_info
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "line #{l}, column #{c}: failed rule '#{info.name}' = '#{info.rendered}'"
      else
        "line #{l}, column #{c}: failed rule '#{@failed_rule}'"
      end
    end

    def failure_caret
      p = current_pos_info @failing_rule_offset
      "#{p.line.chomp}\n#{' ' * (p.col - 1)}^"
    end

    def failure_character
      current_character @failing_rule_offset
    end

    def failure_oneline
      p = current_pos_info @failing_rule_offset

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "@#{p.lno}:#{p.col} failed rule '#{info.name}', got '#{p.char}'"
      else
        "@#{p.lno}:#{p.col} failed rule '#{@failed_rule}', got '#{p.char}'"
      end
    end

    class ParseError < RuntimeError
    end

    def raise_error
      raise ParseError, failure_oneline
    end

    def show_error(io=STDOUT)
      error_pos = @failing_rule_offset
      p = current_pos_info(error_pos)

      io.puts "On line #{p.lno}, column #{p.col}:"

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        io.puts "Failed to match '#{info.rendered}' (rule '#{info.name}')"
      else
        io.puts "Failed to match rule '#{@failed_rule}'"
      end

      io.puts "Got: #{p.char.inspect}"
      io.puts "=> #{p.line}"
      io.print(" " * (p.col + 2))
      io.puts "^"
    end

    def set_failed_rule(name)
      if @pos > @failing_rule_offset
        @failed_rule = name
        @failing_rule_offset = @pos
      end
    end

    attr_reader :failed_rule

    def match_dot()
      if @pos >= @string_size
        return nil
      end

      @pos += 1
      true
    end

    def match_string(str)
      len = str.size
      if @string[pos,len] == str
        @pos += len
        return str
      end

      return nil
    end

    def scan(reg)
      if m = reg.match(@string, @pos)
        @pos = m.end(0)
        return true
      end

      return nil
    end

    if "".respond_to? :ord
      def match_char_range(char_range)
        if @pos >= @string_size
          return nil
        elsif !char_range.include?(@string[@pos].ord)
          return nil
        end

        @pos += 1
        true
      end
    else
      def match_char_range(char_range)
        if @pos >= @string_size
          return nil
        elsif !char_range.include?(@string[@pos])
          return nil
        end

        @pos += 1
        true
      end
    end

    def parse(rule=nil)
      # We invoke the rules indirectly via apply
      # instead of by just calling them as methods because
      # if the rules use left recursion, apply needs to
      # manage that.

      if !rule
        apply(:_root)
      else
        method = rule.gsub("-","_hyphen_")
        apply :"_#{method}"
      end
    end

    class MemoEntry
      def initialize(ans, pos)
        @ans = ans
        @pos = pos
        @result = nil
        @set = false
        @left_rec = false
      end

      attr_reader :ans, :pos, :result, :set
      attr_accessor :left_rec

      def move!(ans, pos, result)
        @ans = ans
        @pos = pos
        @result = result
        @set = true
        @left_rec = false
      end
    end

    def external_invoke(other, rule, *args)
      old_pos = @pos
      old_string = @string

      set_string other.string, other.pos

      begin
        if val = __send__(rule, *args)
          other.pos = @pos
          other.result = @result
        else
          other.set_failed_rule "#{self.class}##{rule}"
        end
        val
      ensure
        set_string old_string, old_pos
      end
    end

    def apply_with_args(rule, *args)
      @result = nil
      memo_key = [rule, args]
      if m = @memoizations[memo_key][@pos]
        @pos = m.pos
        if !m.set
          m.left_rec = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        m = MemoEntry.new(nil, @pos)
        @memoizations[memo_key][@pos] = m
        start_pos = @pos

        ans = __send__ rule, *args

        lr = m.left_rec

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr
          return grow_lr(rule, args, start_pos, m)
        else
          return ans
        end
      end
    end

    def apply(rule)
      @result = nil
      if m = @memoizations[rule][@pos]
        @pos = m.pos
        if !m.set
          m.left_rec = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        m = MemoEntry.new(nil, @pos)
        @memoizations[rule][@pos] = m
        start_pos = @pos

        ans = __send__ rule

        lr = m.left_rec

        m.move! ans, @pos, @result

        # Don't bother trying to grow the left recursion
        # if it's failing straight away (thus there is no seed)
        if ans and lr
          return grow_lr(rule, nil, start_pos, m)
        else
          return ans
        end
      end
    end

    def grow_lr(rule, args, start_pos, m)
      while true
        @pos = start_pos
        @result = m.result

        if args
          ans = __send__ rule, *args
        else
          ans = __send__ rule
        end
        return nil unless ans

        break if @pos <= m.pos

        m.move! ans, @pos, @result
      end

      @result = m.result
      @pos = m.pos
      return m.ans
    end

    class RuleInfo
      def initialize(name, rendered)
        @name = name
        @rendered = rendered
      end

      attr_reader :name, :rendered
    end

    def self.rule_info(name, rendered)
      RuleInfo.new(name, rendered)
    end


  # :startdoc:


    attr_accessor :output


  # :stopdoc:
  def setup_foreign_grammar; end

  # period = "."
  def _period
    _tmp = match_string(".")
    set_failed_rule :_period unless _tmp
    return _tmp
  end

  # space = " "
  def _space
    _tmp = match_string(" ")
    set_failed_rule :_space unless _tmp
    return _tmp
  end

  # alpha = < /[A-Za-z]/ > { text.upcase }
  def _alpha

    _save = self.pos
    begin # sequence
      _text_start = self.pos
      _tmp = scan(/\G(?-mix:[A-Za-z])/)
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text.upcase; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_alpha unless _tmp
    return _tmp
  end

  # word = (alpha:a word:w { "#{a}#{w}" } | alpha:a space { "#{a} "} | alpha:a { a })
  def _word

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = apply(:_alpha)
        a = @result
        break unless _tmp
        _tmp = apply(:_word)
        w = @result
        break unless _tmp
        @result = begin; "#{a}#{w}"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = apply(:_alpha)
        a = @result
        break unless _tmp
        _tmp = apply(:_space)
        break unless _tmp
        @result = begin; "#{a} "; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

      break if _tmp

      _save2 = self.pos
      begin # sequence
        _tmp = apply(:_alpha)
        a = @result
        break unless _tmp
        @result = begin; a; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save2
      end # end sequence

    end while false # end choice

    set_failed_rule :_word unless _tmp
    return _tmp
  end

  # sentence = (word:w sentence:s { "#{w}#{s}" } | word:w { w })
  def _sentence

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = apply(:_word)
        w = @result
        break unless _tmp
        _tmp = apply(:_sentence)
        s = @result
        break unless _tmp
        @result = begin; "#{w}#{s}"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = apply(:_word)
        w = @result
        break unless _tmp
        @result = begin; w; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

    end while false # end choice

    set_failed_rule :_sentence unless _tmp
    return _tmp
  end

  # document = (sentence:s period space* document:d { "#{s}. #{d}" } | sentence:s period { "#{s}." } | sentence:s { "#{s}" })
  def _document

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = apply(:_sentence)
        s = @result
        break unless _tmp
        _tmp = apply(:_period)
        break unless _tmp
        while true # kleene
          _tmp = apply(:_space)
          break unless _tmp
        end
        _tmp = true # end kleene
        break unless _tmp
        _tmp = apply(:_document)
        d = @result
        break unless _tmp
        @result = begin; "#{s}. #{d}"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = apply(:_sentence)
        s = @result
        break unless _tmp
        _tmp = apply(:_period)
        break unless _tmp
        @result = begin; "#{s}."; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

      break if _tmp

      _save2 = self.pos
      begin # sequence
        _tmp = apply(:_sentence)
        s = @result
        break unless _tmp
        @result = begin; "#{s}"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save2
      end # end sequence

    end while false # end choice

    set_failed_rule :_document unless _tmp
    return _tmp
  end

  # root = document:d { @output = d }
  def _root

    _save = self.pos
    begin # sequence
      _tmp = apply(:_document)
      d = @result
      break unless _tmp
      @result = begin; @output = d; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_period] = rule_info("period", "\".\"")
  Rules[:_space] = rule_info("space", "\" \"")
  Rules[:_alpha] = rule_info("alpha", "< /[A-Za-z]/ > { text.upcase }")
  Rules[:_word] = rule_info("word", "(alpha:a word:w { \"\#{a}\#{w}\" } | alpha:a space { \"\#{a} \"} | alpha:a { a })")
  Rules[:_sentence] = rule_info("sentence", "(word:w sentence:s { \"\#{w}\#{s}\" } | word:w { w })")
  Rules[:_document] = rule_info("document", "(sentence:s period space* document:d { \"\#{s}. \#{d}\" } | sentence:s period { \"\#{s}.\" } | sentence:s { \"\#{s}\" })")
  Rules[:_root] = rule_info("root", "document:d { @output = d }")
  # :startdoc:
end
