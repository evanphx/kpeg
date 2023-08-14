require 'kpeg/grammar'
class KPeg::FormatParser
  # :stopdoc:

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



    ##
    # Creates a new kpeg format parser for +str+.

    def initialize(str, debug=false)
      setup_parser(str, debug)
      @g = KPeg::Grammar.new
    end

    ##
    # The parsed grammar

    attr_reader :g

    alias_method :grammar, :g


  # :stopdoc:
  def setup_foreign_grammar; end

  # eol = "\n"
  def _eol
    _tmp = match_string("\n")
    set_failed_rule :_eol unless _tmp
    return _tmp
  end

  # eof_comment = "#" (!eof .)*
  def _eof_comment

    _save = self.pos
    begin # sequence
      _tmp = match_string("#")
      break unless _tmp
      while true # kleene

        _save1 = self.pos
        begin # sequence
          _save2 = self.pos
          _tmp = apply(:_eof)
          _tmp = !_tmp
          self.pos = _save2
          break unless _tmp
          _tmp = match_dot
        end while false
        unless _tmp
          self.pos = _save1
        end # end sequence

        break unless _tmp
      end
      _tmp = true # end kleene
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_eof_comment unless _tmp
    return _tmp
  end

  # comment = "#" (!eol .)* eol
  def _comment

    _save = self.pos
    begin # sequence
      _tmp = match_string("#")
      break unless _tmp
      while true # kleene

        _save1 = self.pos
        begin # sequence
          _save2 = self.pos
          _tmp = apply(:_eol)
          _tmp = !_tmp
          self.pos = _save2
          break unless _tmp
          _tmp = match_dot
        end while false
        unless _tmp
          self.pos = _save1
        end # end sequence

        break unless _tmp
      end
      _tmp = true # end kleene
      break unless _tmp
      _tmp = apply(:_eol)
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_comment unless _tmp
    return _tmp
  end

  # space = (" " | "\t" | eol)
  def _space

    begin # choice
      _tmp = match_string(" ")
      break if _tmp
      _tmp = match_string("\t")
      break if _tmp
      _tmp = apply(:_eol)
    end while false # end choice

    set_failed_rule :_space unless _tmp
    return _tmp
  end

  # - = (space | comment)*
  def __hyphen_
    while true # kleene

      begin # choice
        _tmp = apply(:_space)
        break if _tmp
        _tmp = apply(:_comment)
      end while false # end choice

      break unless _tmp
    end
    _tmp = true # end kleene
    set_failed_rule :__hyphen_ unless _tmp
    return _tmp
  end

  # kleene = "*"
  def _kleene
    _tmp = match_string("*")
    set_failed_rule :_kleene unless _tmp
    return _tmp
  end

  # var = < ("-" | /[a-z][\w-]*/i) > { text }
  def _var

    _save = self.pos
    begin # sequence
      _text_start = self.pos

      begin # choice
        _tmp = match_string("-")
        break if _tmp
        _tmp = scan(/\G(?i-mx:[a-z][\w-]*)/)
      end while false # end choice

      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_var unless _tmp
    return _tmp
  end

  # method = < /[a-z_]\w*/i > { text }
  def _method

    _save = self.pos
    begin # sequence
      _text_start = self.pos
      _tmp = scan(/\G(?i-mx:[a-z_]\w*)/)
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_method unless _tmp
    return _tmp
  end

  # dbl_escapes = ("n" { "\n" } | "s" { " " } | "r" { "\r" } | "t" { "\t" } | "v" { "\v" } | "f" { "\f" } | "b" { "\b" } | "a" { "\a" } | "e" { "\e" } | "\\" { "\\" } | "\"" { "\"" } | num_escapes | < . > { text })
  def _dbl_escapes

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = match_string("n")
        break unless _tmp
        @result = begin; "\n"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = match_string("s")
        break unless _tmp
        @result = begin; " "; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

      break if _tmp

      _save2 = self.pos
      begin # sequence
        _tmp = match_string("r")
        break unless _tmp
        @result = begin; "\r"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save2
      end # end sequence

      break if _tmp

      _save3 = self.pos
      begin # sequence
        _tmp = match_string("t")
        break unless _tmp
        @result = begin; "\t"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save3
      end # end sequence

      break if _tmp

      _save4 = self.pos
      begin # sequence
        _tmp = match_string("v")
        break unless _tmp
        @result = begin; "\v"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save4
      end # end sequence

      break if _tmp

      _save5 = self.pos
      begin # sequence
        _tmp = match_string("f")
        break unless _tmp
        @result = begin; "\f"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save5
      end # end sequence

      break if _tmp

      _save6 = self.pos
      begin # sequence
        _tmp = match_string("b")
        break unless _tmp
        @result = begin; "\b"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save6
      end # end sequence

      break if _tmp

      _save7 = self.pos
      begin # sequence
        _tmp = match_string("a")
        break unless _tmp
        @result = begin; "\a"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save7
      end # end sequence

      break if _tmp

      _save8 = self.pos
      begin # sequence
        _tmp = match_string("e")
        break unless _tmp
        @result = begin; "\e"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save8
      end # end sequence

      break if _tmp

      _save9 = self.pos
      begin # sequence
        _tmp = match_string("\\")
        break unless _tmp
        @result = begin; "\\"; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save9
      end # end sequence

      break if _tmp

      _save10 = self.pos
      begin # sequence
        _tmp = match_string("\"")
        break unless _tmp
        @result = begin; "\""; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save10
      end # end sequence

      break if _tmp
      _tmp = apply(:_num_escapes)
      break if _tmp

      _save11 = self.pos
      begin # sequence
        _text_start = self.pos
        _tmp = match_dot
        if _tmp
          text = get_text(_text_start)
        end
        break unless _tmp
        @result = begin; text; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save11
      end # end sequence

    end while false # end choice

    set_failed_rule :_dbl_escapes unless _tmp
    return _tmp
  end

  # num_escapes = (< /[0-7]{1,3}/ > { [text.to_i(8)].pack("U") } | "x" < /[a-f\d]{2}/i > { [text.to_i(16)].pack("U") })
  def _num_escapes

    begin # choice

      _save = self.pos
      begin # sequence
        _text_start = self.pos
        _tmp = scan(/\G(?-mix:[0-7]{1,3})/)
        if _tmp
          text = get_text(_text_start)
        end
        break unless _tmp
        @result = begin; [text.to_i(8)].pack("U"); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = match_string("x")
        break unless _tmp
        _text_start = self.pos
        _tmp = scan(/\G(?i-mx:[a-f\d]{2})/)
        if _tmp
          text = get_text(_text_start)
        end
        break unless _tmp
        @result = begin; [text.to_i(16)].pack("U"); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

    end while false # end choice

    set_failed_rule :_num_escapes unless _tmp
    return _tmp
  end

  # dbl_seq = < /[^\\"]+/ > { text }
  def _dbl_seq

    _save = self.pos
    begin # sequence
      _text_start = self.pos
      _tmp = scan(/\G(?-mix:[^\\"]+)/)
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_dbl_seq unless _tmp
    return _tmp
  end

  # dbl_not_quote = ("\\" dbl_escapes | dbl_seq)*:ary { Array(ary) }
  def _dbl_not_quote

    _save = self.pos
    begin # sequence
      _ary = [] # kleene
      while true

        begin # choice

          _save1 = self.pos
          begin # sequence
            _tmp = match_string("\\")
            break unless _tmp
            _tmp = apply(:_dbl_escapes)
          end while false
          unless _tmp
            self.pos = _save1
          end # end sequence

          break if _tmp
          _tmp = apply(:_dbl_seq)
        end while false # end choice

        break unless _tmp
        _ary << @result
      end
      @result = _ary
      _tmp = true # end kleene
      ary = @result
      break unless _tmp
      @result = begin; Array(ary); end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_dbl_not_quote unless _tmp
    return _tmp
  end

  # dbl_string = "\"" dbl_not_quote:s "\"" { @g.str(s.join) }
  def _dbl_string

    _save = self.pos
    begin # sequence
      _tmp = match_string("\"")
      break unless _tmp
      _tmp = apply(:_dbl_not_quote)
      s = @result
      break unless _tmp
      _tmp = match_string("\"")
      break unless _tmp
      @result = begin; @g.str(s.join); end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_dbl_string unless _tmp
    return _tmp
  end

  # sgl_escape_quote = "\\'" { "'" }
  def _sgl_escape_quote

    _save = self.pos
    begin # sequence
      _tmp = match_string("\\'")
      break unless _tmp
      @result = begin; "'"; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_sgl_escape_quote unless _tmp
    return _tmp
  end

  # sgl_seq = < /[^']/ > { text }
  def _sgl_seq

    _save = self.pos
    begin # sequence
      _text_start = self.pos
      _tmp = scan(/\G(?-mix:[^'])/)
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_sgl_seq unless _tmp
    return _tmp
  end

  # sgl_not_quote = (sgl_escape_quote | sgl_seq)*:segs { Array(segs) }
  def _sgl_not_quote

    _save = self.pos
    begin # sequence
      _ary = [] # kleene
      while true

        begin # choice
          _tmp = apply(:_sgl_escape_quote)
          break if _tmp
          _tmp = apply(:_sgl_seq)
        end while false # end choice

        break unless _tmp
        _ary << @result
      end
      @result = _ary
      _tmp = true # end kleene
      segs = @result
      break unless _tmp
      @result = begin; Array(segs); end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_sgl_not_quote unless _tmp
    return _tmp
  end

  # sgl_string = "'" sgl_not_quote:s "'" { @g.str(s.join) }
  def _sgl_string

    _save = self.pos
    begin # sequence
      _tmp = match_string("'")
      break unless _tmp
      _tmp = apply(:_sgl_not_quote)
      s = @result
      break unless _tmp
      _tmp = match_string("'")
      break unless _tmp
      @result = begin; @g.str(s.join); end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_sgl_string unless _tmp
    return _tmp
  end

  # string = (dbl_string | sgl_string)
  def _string

    begin # choice
      _tmp = apply(:_dbl_string)
      break if _tmp
      _tmp = apply(:_sgl_string)
    end while false # end choice

    set_failed_rule :_string unless _tmp
    return _tmp
  end

  # not_slash = < ("\\/" | /[^\/]/)+ > { text }
  def _not_slash

    _save = self.pos
    begin # sequence
      _text_start = self.pos
      _save1 = self.pos # repetition
      _count = 0
      while true

        begin # choice
          _tmp = match_string("\\/")
          break if _tmp
          _tmp = scan(/\G(?-mix:[^\/])/)
        end while false # end choice

        break unless _tmp
        _count += 1
      end
      _tmp = _count >= 1
      unless _tmp
        self.pos = _save1
      end # end repetition
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_not_slash unless _tmp
    return _tmp
  end

  # regexp_opts = < [a-z]* > { text }
  def _regexp_opts

    _save = self.pos
    begin # sequence
      _text_start = self.pos
      while true # kleene
        _tmp = match_char_range(97..122)
        break unless _tmp
      end
      _tmp = true # end kleene
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_regexp_opts unless _tmp
    return _tmp
  end

  # regexp = "/" not_slash:body "/" regexp_opts:opts { @g.reg body, opts }
  def _regexp

    _save = self.pos
    begin # sequence
      _tmp = match_string("/")
      break unless _tmp
      _tmp = apply(:_not_slash)
      body = @result
      break unless _tmp
      _tmp = match_string("/")
      break unless _tmp
      _tmp = apply(:_regexp_opts)
      opts = @result
      break unless _tmp
      @result = begin; @g.reg body, opts; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_regexp unless _tmp
    return _tmp
  end

  # char = < /[a-z\d]/i > { text }
  def _char

    _save = self.pos
    begin # sequence
      _text_start = self.pos
      _tmp = scan(/\G(?i-mx:[a-z\d])/)
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_char unless _tmp
    return _tmp
  end

  # char_range = "[" char:l "-" char:r "]" { @g.range(l,r) }
  def _char_range

    _save = self.pos
    begin # sequence
      _tmp = match_string("[")
      break unless _tmp
      _tmp = apply(:_char)
      l = @result
      break unless _tmp
      _tmp = match_string("-")
      break unless _tmp
      _tmp = apply(:_char)
      r = @result
      break unless _tmp
      _tmp = match_string("]")
      break unless _tmp
      @result = begin; @g.range(l,r); end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_char_range unless _tmp
    return _tmp
  end

  # range_num = < /[1-9]\d*/ > { text }
  def _range_num

    _save = self.pos
    begin # sequence
      _text_start = self.pos
      _tmp = scan(/\G(?-mix:[1-9]\d*)/)
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_range_num unless _tmp
    return _tmp
  end

  # range_elem = < (range_num | kleene) > { text }
  def _range_elem

    _save = self.pos
    begin # sequence
      _text_start = self.pos

      begin # choice
        _tmp = apply(:_range_num)
        break if _tmp
        _tmp = apply(:_kleene)
      end while false # end choice

      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_range_elem unless _tmp
    return _tmp
  end

  # mult_range = ("[" - range_elem:l - "," - range_elem:r - "]" { [l == "*" ? nil : l.to_i, r == "*" ? nil : r.to_i] } | "[" - range_num:e - "]" { [e.to_i, e.to_i] })
  def _mult_range

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = match_string("[")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_range_elem)
        l = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string(",")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_range_elem)
        r = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string("]")
        break unless _tmp
        @result = begin; [l == "*" ? nil : l.to_i, r == "*" ? nil : r.to_i]; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = match_string("[")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_range_num)
        e = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string("]")
        break unless _tmp
        @result = begin; [e.to_i, e.to_i]; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

    end while false # end choice

    set_failed_rule :_mult_range unless _tmp
    return _tmp
  end

  # curly_block = curly
  def _curly_block
    _tmp = apply(:_curly)
    set_failed_rule :_curly_block unless _tmp
    return _tmp
  end

  # curly = "{" < (spaces | /[^{}"']+/ | string | curly)* > "}" { @g.action(text) }
  def _curly

    _save = self.pos
    begin # sequence
      _tmp = match_string("{")
      break unless _tmp
      _text_start = self.pos
      while true # kleene

        begin # choice
          _tmp = apply(:_spaces)
          break if _tmp
          _tmp = scan(/\G(?-mix:[^{}"']+)/)
          break if _tmp
          _tmp = apply(:_string)
          break if _tmp
          _tmp = apply(:_curly)
        end while false # end choice

        break unless _tmp
      end
      _tmp = true # end kleene
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      _tmp = match_string("}")
      break unless _tmp
      @result = begin; @g.action(text); end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_curly unless _tmp
    return _tmp
  end

  # nested_paren = "(" (/[^()"']+/ | string | nested_paren)* ")"
  def _nested_paren

    _save = self.pos
    begin # sequence
      _tmp = match_string("(")
      break unless _tmp
      while true # kleene

        begin # choice
          _tmp = scan(/\G(?-mix:[^()"']+)/)
          break if _tmp
          _tmp = apply(:_string)
          break if _tmp
          _tmp = apply(:_nested_paren)
        end while false # end choice

        break unless _tmp
      end
      _tmp = true # end kleene
      break unless _tmp
      _tmp = match_string(")")
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_nested_paren unless _tmp
    return _tmp
  end

  # value = (value:v ":" var:n { @g.t(v,n) } | value:v "?" { @g.maybe(v) } | value:v "+" { @g.many(v) } | value:v "*" { @g.kleene(v) } | value:v mult_range:r { @g.multiple(v, *r) } | "&" value:v { @g.andp(v) } | "!" value:v { @g.notp(v) } | "(" - expression:o - ")" { o } | "@<" - expression:o - ">" { @g.bounds(o) } | "<" - expression:o - ">" { @g.collect(o) } | curly_block | "~" method:m < nested_paren? > { @g.action("#{m}#{text}") } | "." { @g.dot } | "@" var:name < nested_paren? > !(- "=") { @g.invoke(name, text.empty? ? nil : text) } | "^" var:name < nested_paren? > { @g.foreign_invoke("parent", name, text) } | "%" var:gram "." var:name < nested_paren? > { @g.foreign_invoke(gram, name, text) } | var:name < nested_paren? > !(- "=") { @g.ref(name, nil, text.empty? ? nil : text) } | char_range | regexp | string)
  def _value

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = apply(:_value)
        v = @result
        break unless _tmp
        _tmp = match_string(":")
        break unless _tmp
        _tmp = apply(:_var)
        n = @result
        break unless _tmp
        @result = begin; @g.t(v,n); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = apply(:_value)
        v = @result
        break unless _tmp
        _tmp = match_string("?")
        break unless _tmp
        @result = begin; @g.maybe(v); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

      break if _tmp

      _save2 = self.pos
      begin # sequence
        _tmp = apply(:_value)
        v = @result
        break unless _tmp
        _tmp = match_string("+")
        break unless _tmp
        @result = begin; @g.many(v); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save2
      end # end sequence

      break if _tmp

      _save3 = self.pos
      begin # sequence
        _tmp = apply(:_value)
        v = @result
        break unless _tmp
        _tmp = match_string("*")
        break unless _tmp
        @result = begin; @g.kleene(v); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save3
      end # end sequence

      break if _tmp

      _save4 = self.pos
      begin # sequence
        _tmp = apply(:_value)
        v = @result
        break unless _tmp
        _tmp = apply(:_mult_range)
        r = @result
        break unless _tmp
        @result = begin; @g.multiple(v, *r); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save4
      end # end sequence

      break if _tmp

      _save5 = self.pos
      begin # sequence
        _tmp = match_string("&")
        break unless _tmp
        _tmp = apply(:_value)
        v = @result
        break unless _tmp
        @result = begin; @g.andp(v); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save5
      end # end sequence

      break if _tmp

      _save6 = self.pos
      begin # sequence
        _tmp = match_string("!")
        break unless _tmp
        _tmp = apply(:_value)
        v = @result
        break unless _tmp
        @result = begin; @g.notp(v); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save6
      end # end sequence

      break if _tmp

      _save7 = self.pos
      begin # sequence
        _tmp = match_string("(")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_expression)
        o = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string(")")
        break unless _tmp
        @result = begin; o; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save7
      end # end sequence

      break if _tmp

      _save8 = self.pos
      begin # sequence
        _tmp = match_string("@<")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_expression)
        o = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string(">")
        break unless _tmp
        @result = begin; @g.bounds(o); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save8
      end # end sequence

      break if _tmp

      _save9 = self.pos
      begin # sequence
        _tmp = match_string("<")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_expression)
        o = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string(">")
        break unless _tmp
        @result = begin; @g.collect(o); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save9
      end # end sequence

      break if _tmp
      _tmp = apply(:_curly_block)
      break if _tmp

      _save10 = self.pos
      begin # sequence
        _tmp = match_string("~")
        break unless _tmp
        _tmp = apply(:_method)
        m = @result
        break unless _tmp
        _text_start = self.pos
        # optional
        _tmp = apply(:_nested_paren)
        _tmp = true # end optional
        if _tmp
          text = get_text(_text_start)
        end
        break unless _tmp
        @result = begin; @g.action("#{m}#{text}"); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save10
      end # end sequence

      break if _tmp

      _save11 = self.pos
      begin # sequence
        _tmp = match_string(".")
        break unless _tmp
        @result = begin; @g.dot; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save11
      end # end sequence

      break if _tmp

      _save12 = self.pos
      begin # sequence
        _tmp = match_string("@")
        break unless _tmp
        _tmp = apply(:_var)
        name = @result
        break unless _tmp
        _text_start = self.pos
        # optional
        _tmp = apply(:_nested_paren)
        _tmp = true # end optional
        if _tmp
          text = get_text(_text_start)
        end
        break unless _tmp
        _save13 = self.pos

        _save14 = self.pos
        begin # sequence
          _tmp = apply(:__hyphen_)
          break unless _tmp
          _tmp = match_string("=")
        end while false
        unless _tmp
          self.pos = _save14
        end # end sequence

        _tmp = !_tmp
        self.pos = _save13
        break unless _tmp
        @result = begin; @g.invoke(name, text.empty? ? nil : text); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save12
      end # end sequence

      break if _tmp

      _save15 = self.pos
      begin # sequence
        _tmp = match_string("^")
        break unless _tmp
        _tmp = apply(:_var)
        name = @result
        break unless _tmp
        _text_start = self.pos
        # optional
        _tmp = apply(:_nested_paren)
        _tmp = true # end optional
        if _tmp
          text = get_text(_text_start)
        end
        break unless _tmp
        @result = begin; @g.foreign_invoke("parent", name, text); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save15
      end # end sequence

      break if _tmp

      _save16 = self.pos
      begin # sequence
        _tmp = match_string("%")
        break unless _tmp
        _tmp = apply(:_var)
        gram = @result
        break unless _tmp
        _tmp = match_string(".")
        break unless _tmp
        _tmp = apply(:_var)
        name = @result
        break unless _tmp
        _text_start = self.pos
        # optional
        _tmp = apply(:_nested_paren)
        _tmp = true # end optional
        if _tmp
          text = get_text(_text_start)
        end
        break unless _tmp
        @result = begin; @g.foreign_invoke(gram, name, text); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save16
      end # end sequence

      break if _tmp

      _save17 = self.pos
      begin # sequence
        _tmp = apply(:_var)
        name = @result
        break unless _tmp
        _text_start = self.pos
        # optional
        _tmp = apply(:_nested_paren)
        _tmp = true # end optional
        if _tmp
          text = get_text(_text_start)
        end
        break unless _tmp
        _save18 = self.pos

        _save19 = self.pos
        begin # sequence
          _tmp = apply(:__hyphen_)
          break unless _tmp
          _tmp = match_string("=")
        end while false
        unless _tmp
          self.pos = _save19
        end # end sequence

        _tmp = !_tmp
        self.pos = _save18
        break unless _tmp
        @result = begin; @g.ref(name, nil, text.empty? ? nil : text); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save17
      end # end sequence

      break if _tmp
      _tmp = apply(:_char_range)
      break if _tmp
      _tmp = apply(:_regexp)
      break if _tmp
      _tmp = apply(:_string)
    end while false # end choice

    set_failed_rule :_value unless _tmp
    return _tmp
  end

  # spaces = (space | comment)+
  def _spaces
    _save = self.pos # repetition
    _count = 0
    while true

      begin # choice
        _tmp = apply(:_space)
        break if _tmp
        _tmp = apply(:_comment)
      end while false # end choice

      break unless _tmp
      _count += 1
    end
    _tmp = _count >= 1
    unless _tmp
      self.pos = _save
    end # end repetition
    set_failed_rule :_spaces unless _tmp
    return _tmp
  end

  # values = (values:s spaces value:v { @g.seq(s, v) } | value:l spaces value:r { @g.seq(l, r) } | value)
  def _values

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = apply(:_values)
        s = @result
        break unless _tmp
        _tmp = apply(:_spaces)
        break unless _tmp
        _tmp = apply(:_value)
        v = @result
        break unless _tmp
        @result = begin; @g.seq(s, v); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = apply(:_value)
        l = @result
        break unless _tmp
        _tmp = apply(:_spaces)
        break unless _tmp
        _tmp = apply(:_value)
        r = @result
        break unless _tmp
        @result = begin; @g.seq(l, r); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

      break if _tmp
      _tmp = apply(:_value)
    end while false # end choice

    set_failed_rule :_values unless _tmp
    return _tmp
  end

  # choose_cont = - "|" - values:v { v }
  def _choose_cont

    _save = self.pos
    begin # sequence
      _tmp = apply(:__hyphen_)
      break unless _tmp
      _tmp = match_string("|")
      break unless _tmp
      _tmp = apply(:__hyphen_)
      break unless _tmp
      _tmp = apply(:_values)
      v = @result
      break unless _tmp
      @result = begin; v; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_choose_cont unless _tmp
    return _tmp
  end

  # expression = (values:v choose_cont+:alts { @g.any(v, *alts) } | values)
  def _expression

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = apply(:_values)
        v = @result
        break unless _tmp
        _save1 = self.pos # repetition
        _ary = []
        while true
          _tmp = apply(:_choose_cont)
          break unless _tmp
          _ary << @result
        end
        @result = _ary
        _tmp = _ary.size >= 1
        unless _tmp
          self.pos = _save1
          @result = nil
        end # end repetition
        alts = @result
        break unless _tmp
        @result = begin; @g.any(v, *alts); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp
      _tmp = apply(:_values)
    end while false # end choice

    set_failed_rule :_expression unless _tmp
    return _tmp
  end

  # args = (args:a "," - var:n - { a + [n] } | - var:n - { [n] })
  def _args

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = apply(:_args)
        a = @result
        break unless _tmp
        _tmp = match_string(",")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_var)
        n = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        @result = begin; a + [n]; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_var)
        n = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        @result = begin; [n]; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

    end while false # end choice

    set_failed_rule :_args unless _tmp
    return _tmp
  end

  # statement = (- var:v "(" args:a ")" - "=" - expression:o { @g.set(v, o, a) } | - var:v - "=" - expression:o { @g.set(v, o) } | - "%" var:name - "=" - < /[:\w]+/ > { @g.add_foreign_grammar(name, text) } | - "%%" - curly:act { @g.add_setup act } | - "%%" - var:name - curly:act { @g.add_directive name, act } | - "%%" - var:name - "=" - < (!"\n" .)+ > { @g.set_variable(name, text) })
  def _statement

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_var)
        v = @result
        break unless _tmp
        _tmp = match_string("(")
        break unless _tmp
        _tmp = apply(:_args)
        a = @result
        break unless _tmp
        _tmp = match_string(")")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string("=")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_expression)
        o = @result
        break unless _tmp
        @result = begin; @g.set(v, o, a); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_var)
        v = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string("=")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_expression)
        o = @result
        break unless _tmp
        @result = begin; @g.set(v, o); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

      break if _tmp

      _save2 = self.pos
      begin # sequence
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string("%")
        break unless _tmp
        _tmp = apply(:_var)
        name = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string("=")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _text_start = self.pos
        _tmp = scan(/\G(?-mix:[:\w]+)/)
        if _tmp
          text = get_text(_text_start)
        end
        break unless _tmp
        @result = begin; @g.add_foreign_grammar(name, text); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save2
      end # end sequence

      break if _tmp

      _save3 = self.pos
      begin # sequence
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string("%%")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_curly)
        act = @result
        break unless _tmp
        @result = begin; @g.add_setup act; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save3
      end # end sequence

      break if _tmp

      _save4 = self.pos
      begin # sequence
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string("%%")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_var)
        name = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_curly)
        act = @result
        break unless _tmp
        @result = begin; @g.add_directive name, act; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save4
      end # end sequence

      break if _tmp

      _save5 = self.pos
      begin # sequence
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string("%%")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_var)
        name = @result
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = match_string("=")
        break unless _tmp
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _text_start = self.pos
        _save6 = self.pos # repetition
        _count = 0
        while true

          _save7 = self.pos
          begin # sequence
            _save8 = self.pos
            _tmp = match_string("\n")
            _tmp = !_tmp
            self.pos = _save8
            break unless _tmp
            _tmp = match_dot
          end while false
          unless _tmp
            self.pos = _save7
          end # end sequence

          break unless _tmp
          _count += 1
        end
        _tmp = _count >= 1
        unless _tmp
          self.pos = _save6
        end # end repetition
        if _tmp
          text = get_text(_text_start)
        end
        break unless _tmp
        @result = begin; @g.set_variable(name, text); end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save5
      end # end sequence

    end while false # end choice

    set_failed_rule :_statement unless _tmp
    return _tmp
  end

  # statements = statement (- statements)?
  def _statements

    _save = self.pos
    begin # sequence
      _tmp = apply(:_statement)
      break unless _tmp
      # optional

      _save1 = self.pos
      begin # sequence
        _tmp = apply(:__hyphen_)
        break unless _tmp
        _tmp = apply(:_statements)
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

      _tmp = true # end optional
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_statements unless _tmp
    return _tmp
  end

  # eof = !.
  def _eof
    _save = self.pos
    _tmp = match_dot
    _tmp = !_tmp
    self.pos = _save
    set_failed_rule :_eof unless _tmp
    return _tmp
  end

  # root = statements - eof_comment? eof
  def _root

    _save = self.pos
    begin # sequence
      _tmp = apply(:_statements)
      break unless _tmp
      _tmp = apply(:__hyphen_)
      break unless _tmp
      # optional
      _tmp = apply(:_eof_comment)
      _tmp = true # end optional
      break unless _tmp
      _tmp = apply(:_eof)
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  # ast_constant = < /[A-Z]\w*/ > { text }
  def _ast_constant

    _save = self.pos
    begin # sequence
      _text_start = self.pos
      _tmp = scan(/\G(?-mix:[A-Z]\w*)/)
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_ast_constant unless _tmp
    return _tmp
  end

  # ast_word = < /[a-z_]\w*/i > { text }
  def _ast_word

    _save = self.pos
    begin # sequence
      _text_start = self.pos
      _tmp = scan(/\G(?i-mx:[a-z_]\w*)/)
      if _tmp
        text = get_text(_text_start)
      end
      break unless _tmp
      @result = begin; text; end
      _tmp = true
    end while false
    unless _tmp
      self.pos = _save
    end # end sequence

    set_failed_rule :_ast_word unless _tmp
    return _tmp
  end

  # ast_sp = (" " | "\t")*
  def _ast_sp
    while true # kleene

      begin # choice
        _tmp = match_string(" ")
        break if _tmp
        _tmp = match_string("\t")
      end while false # end choice

      break unless _tmp
    end
    _tmp = true # end kleene
    set_failed_rule :_ast_sp unless _tmp
    return _tmp
  end

  # ast_words = (ast_words:r ast_sp "," ast_sp ast_word:w { r + [w] } | ast_word:w { [w] })
  def _ast_words

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = apply(:_ast_words)
        r = @result
        break unless _tmp
        _tmp = apply(:_ast_sp)
        break unless _tmp
        _tmp = match_string(",")
        break unless _tmp
        _tmp = apply(:_ast_sp)
        break unless _tmp
        _tmp = apply(:_ast_word)
        w = @result
        break unless _tmp
        @result = begin; r + [w]; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = apply(:_ast_word)
        w = @result
        break unless _tmp
        @result = begin; [w]; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

    end while false # end choice

    set_failed_rule :_ast_words unless _tmp
    return _tmp
  end

  # ast_root = (ast_constant:c "(" ast_words:w ")" { [c, w] } | ast_constant:c "()"? { [c, []] })
  def _ast_root

    begin # choice

      _save = self.pos
      begin # sequence
        _tmp = apply(:_ast_constant)
        c = @result
        break unless _tmp
        _tmp = match_string("(")
        break unless _tmp
        _tmp = apply(:_ast_words)
        w = @result
        break unless _tmp
        _tmp = match_string(")")
        break unless _tmp
        @result = begin; [c, w]; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save
      end # end sequence

      break if _tmp

      _save1 = self.pos
      begin # sequence
        _tmp = apply(:_ast_constant)
        c = @result
        break unless _tmp
        # optional
        _tmp = match_string("()")
        _tmp = true # end optional
        break unless _tmp
        @result = begin; [c, []]; end
        _tmp = true
      end while false
      unless _tmp
        self.pos = _save1
      end # end sequence

    end while false # end choice

    set_failed_rule :_ast_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_eol] = rule_info("eol", "\"\\n\"")
  Rules[:_eof_comment] = rule_info("eof_comment", "\"\#\" (!eof .)*")
  Rules[:_comment] = rule_info("comment", "\"\#\" (!eol .)* eol")
  Rules[:_space] = rule_info("space", "(\" \" | \"\\t\" | eol)")
  Rules[:__hyphen_] = rule_info("-", "(space | comment)*")
  Rules[:_kleene] = rule_info("kleene", "\"*\"")
  Rules[:_var] = rule_info("var", "< (\"-\" | /[a-z][\\w-]*/i) > { text }")
  Rules[:_method] = rule_info("method", "< /[a-z_]\\w*/i > { text }")
  Rules[:_dbl_escapes] = rule_info("dbl_escapes", "(\"n\" { \"\\n\" } | \"s\" { \" \" } | \"r\" { \"\\r\" } | \"t\" { \"\\t\" } | \"v\" { \"\\v\" } | \"f\" { \"\\f\" } | \"b\" { \"\\b\" } | \"a\" { \"\\a\" } | \"e\" { \"\\e\" } | \"\\\\\" { \"\\\\\" } | \"\\\"\" { \"\\\"\" } | num_escapes | < . > { text })")
  Rules[:_num_escapes] = rule_info("num_escapes", "(< /[0-7]{1,3}/ > { [text.to_i(8)].pack(\"U\") } | \"x\" < /[a-f\\d]{2}/i > { [text.to_i(16)].pack(\"U\") })")
  Rules[:_dbl_seq] = rule_info("dbl_seq", "< /[^\\\\\"]+/ > { text }")
  Rules[:_dbl_not_quote] = rule_info("dbl_not_quote", "(\"\\\\\" dbl_escapes | dbl_seq)*:ary { Array(ary) }")
  Rules[:_dbl_string] = rule_info("dbl_string", "\"\\\"\" dbl_not_quote:s \"\\\"\" { @g.str(s.join) }")
  Rules[:_sgl_escape_quote] = rule_info("sgl_escape_quote", "\"\\\\'\" { \"'\" }")
  Rules[:_sgl_seq] = rule_info("sgl_seq", "< /[^']/ > { text }")
  Rules[:_sgl_not_quote] = rule_info("sgl_not_quote", "(sgl_escape_quote | sgl_seq)*:segs { Array(segs) }")
  Rules[:_sgl_string] = rule_info("sgl_string", "\"'\" sgl_not_quote:s \"'\" { @g.str(s.join) }")
  Rules[:_string] = rule_info("string", "(dbl_string | sgl_string)")
  Rules[:_not_slash] = rule_info("not_slash", "< (\"\\\\/\" | /[^\\/]/)+ > { text }")
  Rules[:_regexp_opts] = rule_info("regexp_opts", "< [a-z]* > { text }")
  Rules[:_regexp] = rule_info("regexp", "\"/\" not_slash:body \"/\" regexp_opts:opts { @g.reg body, opts }")
  Rules[:_char] = rule_info("char", "< /[a-z\\d]/i > { text }")
  Rules[:_char_range] = rule_info("char_range", "\"[\" char:l \"-\" char:r \"]\" { @g.range(l,r) }")
  Rules[:_range_num] = rule_info("range_num", "< /[1-9]\\d*/ > { text }")
  Rules[:_range_elem] = rule_info("range_elem", "< (range_num | kleene) > { text }")
  Rules[:_mult_range] = rule_info("mult_range", "(\"[\" - range_elem:l - \",\" - range_elem:r - \"]\" { [l == \"*\" ? nil : l.to_i, r == \"*\" ? nil : r.to_i] } | \"[\" - range_num:e - \"]\" { [e.to_i, e.to_i] })")
  Rules[:_curly_block] = rule_info("curly_block", "curly")
  Rules[:_curly] = rule_info("curly", "\"{\" < (spaces | /[^{}\"']+/ | string | curly)* > \"}\" { @g.action(text) }")
  Rules[:_nested_paren] = rule_info("nested_paren", "\"(\" (/[^()\"']+/ | string | nested_paren)* \")\"")
  Rules[:_value] = rule_info("value", "(value:v \":\" var:n { @g.t(v,n) } | value:v \"?\" { @g.maybe(v) } | value:v \"+\" { @g.many(v) } | value:v \"*\" { @g.kleene(v) } | value:v mult_range:r { @g.multiple(v, *r) } | \"&\" value:v { @g.andp(v) } | \"!\" value:v { @g.notp(v) } | \"(\" - expression:o - \")\" { o } | \"@<\" - expression:o - \">\" { @g.bounds(o) } | \"<\" - expression:o - \">\" { @g.collect(o) } | curly_block | \"~\" method:m < nested_paren? > { @g.action(\"\#{m}\#{text}\") } | \".\" { @g.dot } | \"@\" var:name < nested_paren? > !(- \"=\") { @g.invoke(name, text.empty? ? nil : text) } | \"^\" var:name < nested_paren? > { @g.foreign_invoke(\"parent\", name, text) } | \"%\" var:gram \".\" var:name < nested_paren? > { @g.foreign_invoke(gram, name, text) } | var:name < nested_paren? > !(- \"=\") { @g.ref(name, nil, text.empty? ? nil : text) } | char_range | regexp | string)")
  Rules[:_spaces] = rule_info("spaces", "(space | comment)+")
  Rules[:_values] = rule_info("values", "(values:s spaces value:v { @g.seq(s, v) } | value:l spaces value:r { @g.seq(l, r) } | value)")
  Rules[:_choose_cont] = rule_info("choose_cont", "- \"|\" - values:v { v }")
  Rules[:_expression] = rule_info("expression", "(values:v choose_cont+:alts { @g.any(v, *alts) } | values)")
  Rules[:_args] = rule_info("args", "(args:a \",\" - var:n - { a + [n] } | - var:n - { [n] })")
  Rules[:_statement] = rule_info("statement", "(- var:v \"(\" args:a \")\" - \"=\" - expression:o { @g.set(v, o, a) } | - var:v - \"=\" - expression:o { @g.set(v, o) } | - \"%\" var:name - \"=\" - < /[:\\w]+/ > { @g.add_foreign_grammar(name, text) } | - \"%%\" - curly:act { @g.add_setup act } | - \"%%\" - var:name - curly:act { @g.add_directive name, act } | - \"%%\" - var:name - \"=\" - < (!\"\\n\" .)+ > { @g.set_variable(name, text) })")
  Rules[:_statements] = rule_info("statements", "statement (- statements)?")
  Rules[:_eof] = rule_info("eof", "!.")
  Rules[:_root] = rule_info("root", "statements - eof_comment? eof")
  Rules[:_ast_constant] = rule_info("ast_constant", "< /[A-Z]\\w*/ > { text }")
  Rules[:_ast_word] = rule_info("ast_word", "< /[a-z_]\\w*/i > { text }")
  Rules[:_ast_sp] = rule_info("ast_sp", "(\" \" | \"\\t\")*")
  Rules[:_ast_words] = rule_info("ast_words", "(ast_words:r ast_sp \",\" ast_sp ast_word:w { r + [w] } | ast_word:w { [w] })")
  Rules[:_ast_root] = rule_info("ast_root", "(ast_constant:c \"(\" ast_words:w \")\" { [c, w] } | ast_constant:c \"()\"? { [c, []] })")
  # :startdoc:
end
