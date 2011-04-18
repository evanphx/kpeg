class KPeg::FormatParser
# STANDALONE START
    def setup_parser(str, debug=false)
      @string = str
      @pos = 0
      @memoizations = Hash.new { |h,k| h[k] = {} }
      @result = nil
      @failed_rule = nil
      @failing_rule_offset = -1

      setup_foreign_grammar
    end

    # This is distinct from setup_parser so that a standalone parser
    # can redefine #initialize and still have access to the proper
    # parser setup code.
    #
    def initialize(str, debug=false)
      setup_parser(str, debug)
    end

    attr_reader :string
    attr_reader :result, :failing_rule_offset
    attr_accessor :pos

    # STANDALONE START
    def current_column(target=pos)
      if c = string.rindex("\n", target-1)
        return target - c - 1
      end

      target + 1
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

    #

    def get_text(start)
      @string[start..@pos-1]
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
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      line = lines[l-1]
      "#{line}\n#{' ' * (c - 1)}^"
    end

    def failure_character
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset
      lines[l-1][c-1, 1]
    end

    def failure_oneline
      l = current_line @failing_rule_offset
      c = current_column @failing_rule_offset

      char = lines[l-1][c-1, 1]

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        "@#{l}:#{c} failed rule '#{info.name}', got '#{char}'"
      else
        "@#{l}:#{c} failed rule '#{@failed_rule}', got '#{char}'"
      end
    end

    class ParseError < RuntimeError
    end

    def raise_error
      raise ParseError, failure_oneline
    end

    def show_error(io=STDOUT)
      error_pos = @failing_rule_offset
      line_no = current_line(error_pos)
      col_no = current_column(error_pos)

      io.puts "On line #{line_no}, column #{col_no}:"

      if @failed_rule.kind_of? Symbol
        info = self.class::Rules[@failed_rule]
        io.puts "Failed to match '#{info.rendered}' (rule '#{info.name}')"
      else
        io.puts "Failed to match rule '#{@failed_rule}'"
      end

      io.puts "Got: #{string[error_pos,1].inspect}"
      line = lines[line_no-1]
      io.puts "=> #{line}"
      io.print(" " * (col_no + 3))
      io.puts "^"
    end

    def set_failed_rule(name)
      if @pos > @failing_rule_offset
        @failed_rule = name
        @failing_rule_offset = @pos
      end
    end

    attr_reader :failed_rule

    def match_string(str)
      len = str.size
      if @string[pos,len] == str
        @pos += len
        return str
      end

      return nil
    end

    def scan(reg)
      if m = reg.match(@string[@pos..-1])
        width = m.end(0)
        @pos += width
        return true
      end

      return nil
    end

    if "".respond_to? :getbyte
      def get_byte
        if @pos >= @string.size
          return nil
        end

        s = @string.getbyte @pos
        @pos += 1
        s
      end
    else
      def get_byte
        if @pos >= @string.size
          return nil
        end

        s = @string[@pos]
        @pos += 1
        s
      end
    end

    def parse(rule=nil)
      if !rule
        _root ? true : false
      else
        # This is not shared with code_generator.rb so this can be standalone
        method = rule.gsub("-","_hyphen_")
        __send__("_#{method}") ? true : false
      end
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
        @result = nil
      end

      attr_reader :ans, :pos, :uses, :result

      def inc!
        @uses += 1
      end

      def move!(ans, pos, result)
        @ans = ans
        @pos = pos
        @result = result
      end
    end

    def external_invoke(other, rule, *args)
      old_pos = @pos
      old_string = @string

      @pos = other.pos
      @string = other.string

      begin
        if val = __send__(rule, *args)
          other.pos = @pos
        else
          other.set_failed_rule "#{self.class}##{rule}"
        end
        val
      ensure
        @pos = old_pos
        @string = old_string
      end
    end

    def apply(rule)
      if m = @memoizations[rule][@pos]
        m.inc!

        prev = @pos
        @pos = m.pos
        if m.ans.kind_of? LeftRecursive
          m.ans.detected = true
          return nil
        end

        @result = m.result

        return m.ans
      else
        lr = LeftRecursive.new(false)
        m = MemoEntry.new(lr, @pos)
        @memoizations[rule][@pos] = m
        start_pos = @pos

        ans = __send__ rule

        m.move! ans, @pos, @result

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
        @pos = start_pos
        @result = m.result

        ans = __send__ rule
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

    #


    require 'kpeg/grammar'

    def initialize(str, debug=false)
      setup_parser(str, debug)
      @g = KPeg::Grammar.new
    end

    attr_reader :g
    alias_method :grammar, :g


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
    while true # sequence
      _tmp = match_string("#")
      unless _tmp
        self.pos = _save
        break
      end
      while true

        _save2 = self.pos
        while true # sequence
          _save3 = self.pos
          _tmp = apply(:_eof)
          _tmp = _tmp ? nil : true
          self.pos = _save3
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = get_byte
          unless _tmp
            self.pos = _save2
          end
          break
        end # end sequence

        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_eof_comment unless _tmp
    return _tmp
  end

  # comment = "#" (!eol .)* eol
  def _comment

    _save = self.pos
    while true # sequence
      _tmp = match_string("#")
      unless _tmp
        self.pos = _save
        break
      end
      while true

        _save2 = self.pos
        while true # sequence
          _save3 = self.pos
          _tmp = apply(:_eol)
          _tmp = _tmp ? nil : true
          self.pos = _save3
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = get_byte
          unless _tmp
            self.pos = _save2
          end
          break
        end # end sequence

        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_eol)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_comment unless _tmp
    return _tmp
  end

  # space = (" " | "\t" | eol)
  def _space

    _save = self.pos
    while true # choice
      _tmp = match_string(" ")
      break if _tmp
      self.pos = _save
      _tmp = match_string("\t")
      break if _tmp
      self.pos = _save
      _tmp = apply(:_eol)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_space unless _tmp
    return _tmp
  end

  # - = (space | comment)*
  def __hyphen_
    while true

      _save1 = self.pos
      while true # choice
        _tmp = apply(:_space)
        break if _tmp
        self.pos = _save1
        _tmp = apply(:_comment)
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      break unless _tmp
    end
    _tmp = true
    set_failed_rule :__hyphen_ unless _tmp
    return _tmp
  end

  # kleene = "*"
  def _kleene
    _tmp = match_string("*")
    set_failed_rule :_kleene unless _tmp
    return _tmp
  end

  # var = < ("-" | /[a-zA-Z][\-_a-zA-Z0-9]*/) > { text }
  def _var

    _save = self.pos
    while true # sequence
      _text_start = self.pos

      _save1 = self.pos
      while true # choice
        _tmp = match_string("-")
        break if _tmp
        self.pos = _save1
        _tmp = scan(/\A(?-mix:[a-zA-Z][\-_a-zA-Z0-9]*)/)
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_var unless _tmp
    return _tmp
  end

  # method = < /[a-zA-Z_][a-zA-Z0-9_]*/ > { text }
  def _method

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[a-zA-Z_][a-zA-Z0-9_]*)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_method unless _tmp
    return _tmp
  end

  # dbl_escapes = ("\\\"" { '"' } | "\\n" { "\n" } | "\\t" { "\t" } | "\\b" { "\b" } | "\\\\" { "\\" })
  def _dbl_escapes

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("\\\"")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  '"' ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = match_string("\\n")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  "\n" ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = match_string("\\t")
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin;  "\t" ; end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _tmp = match_string("\\b")
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin;  "\b" ; end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save5 = self.pos
      while true # sequence
        _tmp = match_string("\\\\")
        unless _tmp
          self.pos = _save5
          break
        end
        @result = begin;  "\\" ; end
        _tmp = true
        unless _tmp
          self.pos = _save5
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_dbl_escapes unless _tmp
    return _tmp
  end

  # dbl_seq = < /[^\\"]+/ > { text }
  def _dbl_seq

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[^\\"]+)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_dbl_seq unless _tmp
    return _tmp
  end

  # dbl_not_quote = (dbl_escapes:s | dbl_seq:s)+:ary { ary }
  def _dbl_not_quote

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []

      _save2 = self.pos
      while true # choice
        _tmp = apply(:_dbl_escapes)
        s = @result
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_dbl_seq)
        s = @result
        break if _tmp
        self.pos = _save2
        break
      end # end choice

      if _tmp
        _ary << @result
        while true

          _save3 = self.pos
          while true # choice
            _tmp = apply(:_dbl_escapes)
            s = @result
            break if _tmp
            self.pos = _save3
            _tmp = apply(:_dbl_seq)
            s = @result
            break if _tmp
            self.pos = _save3
            break
          end # end choice

          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      ary = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  ary ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_dbl_not_quote unless _tmp
    return _tmp
  end

  # dbl_string = "\"" dbl_not_quote:s "\"" { @g.str(s.join) }
  def _dbl_string

    _save = self.pos
    while true # sequence
      _tmp = match_string("\"")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_dbl_not_quote)
      s = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("\"")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @g.str(s.join) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_dbl_string unless _tmp
    return _tmp
  end

  # sgl_escape_quote = "\\'" { "'" }
  def _sgl_escape_quote

    _save = self.pos
    while true # sequence
      _tmp = match_string("\\'")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  "'" ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_sgl_escape_quote unless _tmp
    return _tmp
  end

  # sgl_seq = < /[^']/ > { text }
  def _sgl_seq

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[^'])/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_sgl_seq unless _tmp
    return _tmp
  end

  # sgl_not_quote = (sgl_escape_quote | sgl_seq)+:segs { segs.join }
  def _sgl_not_quote

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []

      _save2 = self.pos
      while true # choice
        _tmp = apply(:_sgl_escape_quote)
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_sgl_seq)
        break if _tmp
        self.pos = _save2
        break
      end # end choice

      if _tmp
        _ary << @result
        while true

          _save3 = self.pos
          while true # choice
            _tmp = apply(:_sgl_escape_quote)
            break if _tmp
            self.pos = _save3
            _tmp = apply(:_sgl_seq)
            break if _tmp
            self.pos = _save3
            break
          end # end choice

          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      segs = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  segs.join ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_sgl_not_quote unless _tmp
    return _tmp
  end

  # sgl_string = "'" sgl_not_quote:s "'" { @g.str(s) }
  def _sgl_string

    _save = self.pos
    while true # sequence
      _tmp = match_string("'")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_sgl_not_quote)
      s = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("'")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @g.str(s) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_sgl_string unless _tmp
    return _tmp
  end

  # string = (dbl_string | sgl_string)
  def _string

    _save = self.pos
    while true # choice
      _tmp = apply(:_dbl_string)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_sgl_string)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_string unless _tmp
    return _tmp
  end

  # not_slash = < ("\\/" | /[^\/]/)+ > { text }
  def _not_slash

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _save1 = self.pos

      _save2 = self.pos
      while true # choice
        _tmp = match_string("\\/")
        break if _tmp
        self.pos = _save2
        _tmp = scan(/\A(?-mix:[^\/])/)
        break if _tmp
        self.pos = _save2
        break
      end # end choice

      if _tmp
        while true

          _save3 = self.pos
          while true # choice
            _tmp = match_string("\\/")
            break if _tmp
            self.pos = _save3
            _tmp = scan(/\A(?-mix:[^\/])/)
            break if _tmp
            self.pos = _save3
            break
          end # end choice

          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save1
      end
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_not_slash unless _tmp
    return _tmp
  end

  # regexp_opts = < [a-z]* > { text }
  def _regexp_opts

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      while true
        _save2 = self.pos
        _tmp = get_byte
        if _tmp
          unless _tmp >= 97 and _tmp <= 122
            self.pos = _save2
            _tmp = nil
          end
        end
        break unless _tmp
      end
      _tmp = true
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_regexp_opts unless _tmp
    return _tmp
  end

  # regexp = "/" not_slash:body "/" regexp_opts:opts { @g.reg body, opts }
  def _regexp

    _save = self.pos
    while true # sequence
      _tmp = match_string("/")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_not_slash)
      body = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("/")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_regexp_opts)
      opts = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @g.reg body, opts ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_regexp unless _tmp
    return _tmp
  end

  # char = < /[a-zA-Z0-9]/ > { text }
  def _char

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[a-zA-Z0-9])/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_char unless _tmp
    return _tmp
  end

  # char_range = "[" char:l "-" char:r "]" { @g.range(l,r) }
  def _char_range

    _save = self.pos
    while true # sequence
      _tmp = match_string("[")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_char)
      l = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("-")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_char)
      r = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("]")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @g.range(l,r) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_char_range unless _tmp
    return _tmp
  end

  # range_num = < /[1-9][0-9]*/ > { text }
  def _range_num

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[1-9][0-9]*)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_range_num unless _tmp
    return _tmp
  end

  # range_elem = < (range_num | kleene) > { text }
  def _range_elem

    _save = self.pos
    while true # sequence
      _text_start = self.pos

      _save1 = self.pos
      while true # choice
        _tmp = apply(:_range_num)
        break if _tmp
        self.pos = _save1
        _tmp = apply(:_kleene)
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_range_elem unless _tmp
    return _tmp
  end

  # mult_range = ("[" - range_elem:l - "," - range_elem:r - "]" { [l == "*" ? nil : l.to_i, r == "*" ? nil : r.to_i] } | "[" - range_num:e - "]" { [e.to_i, e.to_i] })
  def _mult_range

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("[")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_range_elem)
        l = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string(",")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_range_elem)
        r = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("]")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  [l == "*" ? nil : l.to_i, r == "*" ? nil : r.to_i] ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = match_string("[")
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_range_num)
        e = @result
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string("]")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  [e.to_i, e.to_i] ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_mult_range unless _tmp
    return _tmp
  end

  # curly_block = curly
  def _curly_block
    _tmp = apply(:_curly)
    set_failed_rule :_curly_block unless _tmp
    return _tmp
  end

  # curly = "{" < (/[^{}"']+/ | string | curly)* > "}" { @g.action(text) }
  def _curly

    _save = self.pos
    while true # sequence
      _tmp = match_string("{")
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      while true

        _save2 = self.pos
        while true # choice
          _tmp = scan(/\A(?-mix:[^{}"']+)/)
          break if _tmp
          self.pos = _save2
          _tmp = apply(:_string)
          break if _tmp
          self.pos = _save2
          _tmp = apply(:_curly)
          break if _tmp
          self.pos = _save2
          break
        end # end choice

        break unless _tmp
      end
      _tmp = true
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("}")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @g.action(text) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_curly unless _tmp
    return _tmp
  end

  # nested_paren = "(" (/[^()]+/ | nested_paren)* ")"
  def _nested_paren

    _save = self.pos
    while true # sequence
      _tmp = match_string("(")
      unless _tmp
        self.pos = _save
        break
      end
      while true

        _save2 = self.pos
        while true # choice
          _tmp = scan(/\A(?-mix:[^()]+)/)
          break if _tmp
          self.pos = _save2
          _tmp = apply(:_nested_paren)
          break if _tmp
          self.pos = _save2
          break
        end # end choice

        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string(")")
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_nested_paren unless _tmp
    return _tmp
  end

  # value = (value:v ":" var:n { @g.t(v,n) } | value:v "?" { @g.maybe(v) } | value:v "+" { @g.many(v) } | value:v "*" { @g.kleene(v) } | value:v mult_range:r { @g.multiple(v, *r) } | "&" value:v { @g.andp(v) } | "!" value:v { @g.notp(v) } | "(" - expression:o - ")" { o } | "@<" - expression:o - ">" { @g.bounds(o) } | "<" - expression:o - ">" { @g.collect(o) } | curly_block | "~" method:m < nested_paren? > { @g.action("#{m}#{text}") } | "." { @g.dot } | "@" var:name !(- "=") { @g.invoke(name) } | "^" var:name < nested_paren? > { @g.foreign_invoke("parent", name, text) } | "%" var:gram "." var:name < nested_paren? > { @g.foreign_invoke(gram, name, text) } | var:name < nested_paren? > !(- "=") { text.empty? ? @g.ref(name) : @g.invoke(name, text) } | char_range | regexp | string)
  def _value

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_value)
        v = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string(":")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_var)
        n = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  @g.t(v,n) ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_value)
        v = @result
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string("?")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  @g.maybe(v) ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = apply(:_value)
        v = @result
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = match_string("+")
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin;  @g.many(v) ; end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _tmp = apply(:_value)
        v = @result
        unless _tmp
          self.pos = _save4
          break
        end
        _tmp = match_string("*")
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin;  @g.kleene(v) ; end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save5 = self.pos
      while true # sequence
        _tmp = apply(:_value)
        v = @result
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = apply(:_mult_range)
        r = @result
        unless _tmp
          self.pos = _save5
          break
        end
        @result = begin;  @g.multiple(v, *r) ; end
        _tmp = true
        unless _tmp
          self.pos = _save5
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save6 = self.pos
      while true # sequence
        _tmp = match_string("&")
        unless _tmp
          self.pos = _save6
          break
        end
        _tmp = apply(:_value)
        v = @result
        unless _tmp
          self.pos = _save6
          break
        end
        @result = begin;  @g.andp(v) ; end
        _tmp = true
        unless _tmp
          self.pos = _save6
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save7 = self.pos
      while true # sequence
        _tmp = match_string("!")
        unless _tmp
          self.pos = _save7
          break
        end
        _tmp = apply(:_value)
        v = @result
        unless _tmp
          self.pos = _save7
          break
        end
        @result = begin;  @g.notp(v) ; end
        _tmp = true
        unless _tmp
          self.pos = _save7
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save8 = self.pos
      while true # sequence
        _tmp = match_string("(")
        unless _tmp
          self.pos = _save8
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save8
          break
        end
        _tmp = apply(:_expression)
        o = @result
        unless _tmp
          self.pos = _save8
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save8
          break
        end
        _tmp = match_string(")")
        unless _tmp
          self.pos = _save8
          break
        end
        @result = begin;  o ; end
        _tmp = true
        unless _tmp
          self.pos = _save8
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save9 = self.pos
      while true # sequence
        _tmp = match_string("@<")
        unless _tmp
          self.pos = _save9
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save9
          break
        end
        _tmp = apply(:_expression)
        o = @result
        unless _tmp
          self.pos = _save9
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save9
          break
        end
        _tmp = match_string(">")
        unless _tmp
          self.pos = _save9
          break
        end
        @result = begin;  @g.bounds(o) ; end
        _tmp = true
        unless _tmp
          self.pos = _save9
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save10 = self.pos
      while true # sequence
        _tmp = match_string("<")
        unless _tmp
          self.pos = _save10
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save10
          break
        end
        _tmp = apply(:_expression)
        o = @result
        unless _tmp
          self.pos = _save10
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save10
          break
        end
        _tmp = match_string(">")
        unless _tmp
          self.pos = _save10
          break
        end
        @result = begin;  @g.collect(o) ; end
        _tmp = true
        unless _tmp
          self.pos = _save10
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_curly_block)
      break if _tmp
      self.pos = _save

      _save11 = self.pos
      while true # sequence
        _tmp = match_string("~")
        unless _tmp
          self.pos = _save11
          break
        end
        _tmp = apply(:_method)
        m = @result
        unless _tmp
          self.pos = _save11
          break
        end
        _text_start = self.pos
        _save12 = self.pos
        _tmp = apply(:_nested_paren)
        unless _tmp
          _tmp = true
          self.pos = _save12
        end
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save11
          break
        end
        @result = begin;  @g.action("#{m}#{text}") ; end
        _tmp = true
        unless _tmp
          self.pos = _save11
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save13 = self.pos
      while true # sequence
        _tmp = match_string(".")
        unless _tmp
          self.pos = _save13
          break
        end
        @result = begin;  @g.dot ; end
        _tmp = true
        unless _tmp
          self.pos = _save13
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save14 = self.pos
      while true # sequence
        _tmp = match_string("@")
        unless _tmp
          self.pos = _save14
          break
        end
        _tmp = apply(:_var)
        name = @result
        unless _tmp
          self.pos = _save14
          break
        end
        _save15 = self.pos

        _save16 = self.pos
        while true # sequence
          _tmp = apply(:__hyphen_)
          unless _tmp
            self.pos = _save16
            break
          end
          _tmp = match_string("=")
          unless _tmp
            self.pos = _save16
          end
          break
        end # end sequence

        _tmp = _tmp ? nil : true
        self.pos = _save15
        unless _tmp
          self.pos = _save14
          break
        end
        @result = begin;  @g.invoke(name) ; end
        _tmp = true
        unless _tmp
          self.pos = _save14
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save17 = self.pos
      while true # sequence
        _tmp = match_string("^")
        unless _tmp
          self.pos = _save17
          break
        end
        _tmp = apply(:_var)
        name = @result
        unless _tmp
          self.pos = _save17
          break
        end
        _text_start = self.pos
        _save18 = self.pos
        _tmp = apply(:_nested_paren)
        unless _tmp
          _tmp = true
          self.pos = _save18
        end
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save17
          break
        end
        @result = begin;  @g.foreign_invoke("parent", name, text) ; end
        _tmp = true
        unless _tmp
          self.pos = _save17
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save19 = self.pos
      while true # sequence
        _tmp = match_string("%")
        unless _tmp
          self.pos = _save19
          break
        end
        _tmp = apply(:_var)
        gram = @result
        unless _tmp
          self.pos = _save19
          break
        end
        _tmp = match_string(".")
        unless _tmp
          self.pos = _save19
          break
        end
        _tmp = apply(:_var)
        name = @result
        unless _tmp
          self.pos = _save19
          break
        end
        _text_start = self.pos
        _save20 = self.pos
        _tmp = apply(:_nested_paren)
        unless _tmp
          _tmp = true
          self.pos = _save20
        end
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save19
          break
        end
        @result = begin;  @g.foreign_invoke(gram, name, text) ; end
        _tmp = true
        unless _tmp
          self.pos = _save19
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save21 = self.pos
      while true # sequence
        _tmp = apply(:_var)
        name = @result
        unless _tmp
          self.pos = _save21
          break
        end
        _text_start = self.pos
        _save22 = self.pos
        _tmp = apply(:_nested_paren)
        unless _tmp
          _tmp = true
          self.pos = _save22
        end
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save21
          break
        end
        _save23 = self.pos

        _save24 = self.pos
        while true # sequence
          _tmp = apply(:__hyphen_)
          unless _tmp
            self.pos = _save24
            break
          end
          _tmp = match_string("=")
          unless _tmp
            self.pos = _save24
          end
          break
        end # end sequence

        _tmp = _tmp ? nil : true
        self.pos = _save23
        unless _tmp
          self.pos = _save21
          break
        end
        @result = begin;  text.empty? ? @g.ref(name) : @g.invoke(name, text) ; end
        _tmp = true
        unless _tmp
          self.pos = _save21
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_char_range)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_regexp)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_string)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_value unless _tmp
    return _tmp
  end

  # spaces = (space | comment)+
  def _spaces
    _save = self.pos

    _save1 = self.pos
    while true # choice
      _tmp = apply(:_space)
      break if _tmp
      self.pos = _save1
      _tmp = apply(:_comment)
      break if _tmp
      self.pos = _save1
      break
    end # end choice

    if _tmp
      while true

        _save2 = self.pos
        while true # choice
          _tmp = apply(:_space)
          break if _tmp
          self.pos = _save2
          _tmp = apply(:_comment)
          break if _tmp
          self.pos = _save2
          break
        end # end choice

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save
    end
    set_failed_rule :_spaces unless _tmp
    return _tmp
  end

  # values = (values:s spaces value:v { @g.seq(s, v) } | value:l spaces value:r { @g.seq(l, r) } | value)
  def _values

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_values)
        s = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_spaces)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_value)
        v = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  @g.seq(s, v) ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_value)
        l = @result
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_spaces)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_value)
        r = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  @g.seq(l, r) ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_value)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_values unless _tmp
    return _tmp
  end

  # choose_cont = - "|" - values:v { v }
  def _choose_cont

    _save = self.pos
    while true # sequence
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("|")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_values)
      v = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  v ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_choose_cont unless _tmp
    return _tmp
  end

  # expression = (values:v choose_cont+:alts { @g.any(v, *alts) } | values)
  def _expression

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_values)
        v = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _save2 = self.pos
        _ary = []
        _tmp = apply(:_choose_cont)
        if _tmp
          _ary << @result
          while true
            _tmp = apply(:_choose_cont)
            _ary << @result if _tmp
            break unless _tmp
          end
          _tmp = true
          @result = _ary
        else
          self.pos = _save2
        end
        alts = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  @g.any(v, *alts) ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_values)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_expression unless _tmp
    return _tmp
  end

  # args = (args:a "," - var:n - { a + [n] } | - var:n - { [n] })
  def _args

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_args)
        a = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string(",")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_var)
        n = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  a + [n] ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_var)
        n = @result
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  [n] ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_args unless _tmp
    return _tmp
  end

  # statement = (- var:v "(" args:a ")" - "=" - expression:o { @g.set(v, o, a) } | - var:v - "=" - expression:o { @g.set(v, o) } | - "%" var:name - "=" - < /[::A-Za-z0-9_]+/ > { @g.add_foreign_grammar(name, text) } | - "%%" - curly:act { @g.add_setup act } | - "%%" - var:name - "=" - < (!"\n" .)+ > { @g.set_variable(name, text) })
  def _statement

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_var)
        v = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("(")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_args)
        a = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string(")")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("=")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_expression)
        o = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  @g.set(v, o, a) ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_var)
        v = @result
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = match_string("=")
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_expression)
        o = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  @g.set(v, o) ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save3 = self.pos
      while true # sequence
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = match_string("%")
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:_var)
        name = @result
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = match_string("=")
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save3
          break
        end
        _text_start = self.pos
        _tmp = scan(/\A(?-mix:[::A-Za-z0-9_]+)/)
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin;  @g.add_foreign_grammar(name, text) ; end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save4 = self.pos
      while true # sequence
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save4
          break
        end
        _tmp = match_string("%%")
        unless _tmp
          self.pos = _save4
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save4
          break
        end
        _tmp = apply(:_curly)
        act = @result
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin;  @g.add_setup act ; end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save5 = self.pos
      while true # sequence
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = match_string("%%")
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = apply(:_var)
        name = @result
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = match_string("=")
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save5
          break
        end
        _text_start = self.pos
        _save6 = self.pos

        _save7 = self.pos
        while true # sequence
          _save8 = self.pos
          _tmp = match_string("\n")
          _tmp = _tmp ? nil : true
          self.pos = _save8
          unless _tmp
            self.pos = _save7
            break
          end
          _tmp = get_byte
          unless _tmp
            self.pos = _save7
          end
          break
        end # end sequence

        if _tmp
          while true

            _save9 = self.pos
            while true # sequence
              _save10 = self.pos
              _tmp = match_string("\n")
              _tmp = _tmp ? nil : true
              self.pos = _save10
              unless _tmp
                self.pos = _save9
                break
              end
              _tmp = get_byte
              unless _tmp
                self.pos = _save9
              end
              break
            end # end sequence

            break unless _tmp
          end
          _tmp = true
        else
          self.pos = _save6
        end
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save5
          break
        end
        @result = begin;  @g.set_variable(name, text) ; end
        _tmp = true
        unless _tmp
          self.pos = _save5
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_statement unless _tmp
    return _tmp
  end

  # statements = statement (- statements)?
  def _statements

    _save = self.pos
    while true # sequence
      _tmp = apply(:_statement)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:__hyphen_)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_statements)
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_statements unless _tmp
    return _tmp
  end

  # eof = !.
  def _eof
    _save = self.pos
    _tmp = get_byte
    _tmp = _tmp ? nil : true
    self.pos = _save
    set_failed_rule :_eof unless _tmp
    return _tmp
  end

  # root = statements - eof_comment? eof
  def _root

    _save = self.pos
    while true # sequence
      _tmp = apply(:_statements)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:__hyphen_)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_eof_comment)
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_eof)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  # ast_constant = < /[A-Z][A-Za-z0-9_]*/ > { text }
  def _ast_constant

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[A-Z][A-Za-z0-9_]*)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ast_constant unless _tmp
    return _tmp
  end

  # ast_word = < /[A-Za-z_][A-Za-z0-9_]*/ > { text }
  def _ast_word

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[A-Za-z_][A-Za-z0-9_]*)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ast_word unless _tmp
    return _tmp
  end

  # ast_sp = (" " | "\t")*
  def _ast_sp
    while true

      _save1 = self.pos
      while true # choice
        _tmp = match_string(" ")
        break if _tmp
        self.pos = _save1
        _tmp = match_string("\t")
        break if _tmp
        self.pos = _save1
        break
      end # end choice

      break unless _tmp
    end
    _tmp = true
    set_failed_rule :_ast_sp unless _tmp
    return _tmp
  end

  # ast_words = (ast_words:r ast_sp "," ast_sp ast_word:w { r + [w] } | ast_word:w { [w] })
  def _ast_words

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_ast_words)
        r = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_ast_sp)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string(",")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_ast_sp)
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_ast_word)
        w = @result
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  r + [w] ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_ast_word)
        w = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  [w] ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_ast_words unless _tmp
    return _tmp
  end

  # ast_root = (ast_constant:c "(" ast_words:w ")" { [c, w] } | ast_constant:c "()"? { [c, []] })
  def _ast_root

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = apply(:_ast_constant)
        c = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("(")
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = apply(:_ast_words)
        w = @result
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string(")")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  [c, w] ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_ast_constant)
        c = @result
        unless _tmp
          self.pos = _save2
          break
        end
        _save3 = self.pos
        _tmp = match_string("()")
        unless _tmp
          _tmp = true
          self.pos = _save3
        end
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  [c, []] ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

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
  Rules[:_var] = rule_info("var", "< (\"-\" | /[a-zA-Z][\\-_a-zA-Z0-9]*/) > { text }")
  Rules[:_method] = rule_info("method", "< /[a-zA-Z_][a-zA-Z0-9_]*/ > { text }")
  Rules[:_dbl_escapes] = rule_info("dbl_escapes", "(\"\\\\\\\"\" { '\"' } | \"\\\\n\" { \"\\n\" } | \"\\\\t\" { \"\\t\" } | \"\\\\b\" { \"\\b\" } | \"\\\\\\\\\" { \"\\\\\" })")
  Rules[:_dbl_seq] = rule_info("dbl_seq", "< /[^\\\\\"]+/ > { text }")
  Rules[:_dbl_not_quote] = rule_info("dbl_not_quote", "(dbl_escapes:s | dbl_seq:s)+:ary { ary }")
  Rules[:_dbl_string] = rule_info("dbl_string", "\"\\\"\" dbl_not_quote:s \"\\\"\" { @g.str(s.join) }")
  Rules[:_sgl_escape_quote] = rule_info("sgl_escape_quote", "\"\\\\'\" { \"'\" }")
  Rules[:_sgl_seq] = rule_info("sgl_seq", "< /[^']/ > { text }")
  Rules[:_sgl_not_quote] = rule_info("sgl_not_quote", "(sgl_escape_quote | sgl_seq)+:segs { segs.join }")
  Rules[:_sgl_string] = rule_info("sgl_string", "\"'\" sgl_not_quote:s \"'\" { @g.str(s) }")
  Rules[:_string] = rule_info("string", "(dbl_string | sgl_string)")
  Rules[:_not_slash] = rule_info("not_slash", "< (\"\\\\/\" | /[^\\/]/)+ > { text }")
  Rules[:_regexp_opts] = rule_info("regexp_opts", "< [a-z]* > { text }")
  Rules[:_regexp] = rule_info("regexp", "\"/\" not_slash:body \"/\" regexp_opts:opts { @g.reg body, opts }")
  Rules[:_char] = rule_info("char", "< /[a-zA-Z0-9]/ > { text }")
  Rules[:_char_range] = rule_info("char_range", "\"[\" char:l \"-\" char:r \"]\" { @g.range(l,r) }")
  Rules[:_range_num] = rule_info("range_num", "< /[1-9][0-9]*/ > { text }")
  Rules[:_range_elem] = rule_info("range_elem", "< (range_num | kleene) > { text }")
  Rules[:_mult_range] = rule_info("mult_range", "(\"[\" - range_elem:l - \",\" - range_elem:r - \"]\" { [l == \"*\" ? nil : l.to_i, r == \"*\" ? nil : r.to_i] } | \"[\" - range_num:e - \"]\" { [e.to_i, e.to_i] })")
  Rules[:_curly_block] = rule_info("curly_block", "curly")
  Rules[:_curly] = rule_info("curly", "\"{\" < (/[^{}\"']+/ | string | curly)* > \"}\" { @g.action(text) }")
  Rules[:_nested_paren] = rule_info("nested_paren", "\"(\" (/[^()]+/ | nested_paren)* \")\"")
  Rules[:_value] = rule_info("value", "(value:v \":\" var:n { @g.t(v,n) } | value:v \"?\" { @g.maybe(v) } | value:v \"+\" { @g.many(v) } | value:v \"*\" { @g.kleene(v) } | value:v mult_range:r { @g.multiple(v, *r) } | \"&\" value:v { @g.andp(v) } | \"!\" value:v { @g.notp(v) } | \"(\" - expression:o - \")\" { o } | \"@<\" - expression:o - \">\" { @g.bounds(o) } | \"<\" - expression:o - \">\" { @g.collect(o) } | curly_block | \"~\" method:m < nested_paren? > { @g.action(\"\#{m}\#{text}\") } | \".\" { @g.dot } | \"@\" var:name !(- \"=\") { @g.invoke(name) } | \"^\" var:name < nested_paren? > { @g.foreign_invoke(\"parent\", name, text) } | \"%\" var:gram \".\" var:name < nested_paren? > { @g.foreign_invoke(gram, name, text) } | var:name < nested_paren? > !(- \"=\") { text.empty? ? @g.ref(name) : @g.invoke(name, text) } | char_range | regexp | string)")
  Rules[:_spaces] = rule_info("spaces", "(space | comment)+")
  Rules[:_values] = rule_info("values", "(values:s spaces value:v { @g.seq(s, v) } | value:l spaces value:r { @g.seq(l, r) } | value)")
  Rules[:_choose_cont] = rule_info("choose_cont", "- \"|\" - values:v { v }")
  Rules[:_expression] = rule_info("expression", "(values:v choose_cont+:alts { @g.any(v, *alts) } | values)")
  Rules[:_args] = rule_info("args", "(args:a \",\" - var:n - { a + [n] } | - var:n - { [n] })")
  Rules[:_statement] = rule_info("statement", "(- var:v \"(\" args:a \")\" - \"=\" - expression:o { @g.set(v, o, a) } | - var:v - \"=\" - expression:o { @g.set(v, o) } | - \"%\" var:name - \"=\" - < /[::A-Za-z0-9_]+/ > { @g.add_foreign_grammar(name, text) } | - \"%%\" - curly:act { @g.add_setup act } | - \"%%\" - var:name - \"=\" - < (!\"\\n\" .)+ > { @g.set_variable(name, text) })")
  Rules[:_statements] = rule_info("statements", "statement (- statements)?")
  Rules[:_eof] = rule_info("eof", "!.")
  Rules[:_root] = rule_info("root", "statements - eof_comment? eof")
  Rules[:_ast_constant] = rule_info("ast_constant", "< /[A-Z][A-Za-z0-9_]*/ > { text }")
  Rules[:_ast_word] = rule_info("ast_word", "< /[A-Za-z_][A-Za-z0-9_]*/ > { text }")
  Rules[:_ast_sp] = rule_info("ast_sp", "(\" \" | \"\\t\")*")
  Rules[:_ast_words] = rule_info("ast_words", "(ast_words:r ast_sp \",\" ast_sp ast_word:w { r + [w] } | ast_word:w { [w] })")
  Rules[:_ast_root] = rule_info("ast_root", "(ast_constant:c \"(\" ast_words:w \")\" { [c, w] } | ast_constant:c \"()\"? { [c, []] })")
end
