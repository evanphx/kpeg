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
      nil
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
      if m = reg.match(@string, @pos)
        @pos = m.end(0)
        return true
      end

      return nil
    end

    if "".respond_to? :ord
      def get_byte
        if @pos >= @string_size
          return nil
        end

        s = @string[@pos].ord
        @pos += 1
        s
      end
    else
      def get_byte
        if @pos >= @string_size
          return nil
        end

        s = @string[@pos]
        @pos += 1
        s
      end
    end

    def sequence(pos, action)
      @pos = pos  unless action
      action ? true : nil
    end

    def look_ahead(pos, action)
      @pos = pos
      action ? true : nil
    end

    def look_negation(pos, action)
      @pos = pos
      action ? nil : true
    end

    def loop_range(range, store)
      _ary = [] if store
      max = range.end && range.max
      count = 0
      save = @pos
      while (!max || count < max) && yield
        count += 1
        if store
          _ary << @result
          @result = nil
        end
      end
      if range.include?(count)
        @result = _ary if store
        true
      else
        @pos = save
        nil
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
    match_string("\n") or set_failed_rule :_eol
  end

  # eof_comment = "#" (!eof .)*
  def _eof_comment
    sequence(self.pos,  # sequence
      match_string("#") &&
      while true  # kleene
        sequence(self.pos,  # sequence
          look_negation(self.pos,
            apply(:_eof)  # end negation
          ) &&
          get_byte  # end sequence
        ) || (break true) # end kleene
      end  # end sequence
    ) or set_failed_rule :_eof_comment
  end

  # comment = "#" (!eol .)* eol
  def _comment
    sequence(self.pos,  # sequence
      match_string("#") &&
      while true  # kleene
        sequence(self.pos,  # sequence
          look_negation(self.pos,
            apply(:_eol)  # end negation
          ) &&
          get_byte  # end sequence
        ) || (break true) # end kleene
      end &&
      apply(:_eol)  # end sequence
    ) or set_failed_rule :_comment
  end

  # space = (" " | "\t" | eol)
  def _space
    ( # choice
      match_string(" ") ||
      match_string("\t") ||
      apply(:_eol)
      # end choice
    ) or set_failed_rule :_space
  end

  # - = (space | comment)*
  def __hyphen_
    while true  # kleene
      ( # choice
        apply(:_space) ||
        apply(:_comment)
        # end choice
      ) || (break true) # end kleene
    end or set_failed_rule :__hyphen_
  end

  # kleene = "*"
  def _kleene
    match_string("*") or set_failed_rule :_kleene
  end

  # var = < ("-" | /[a-z][\w-]*/i) > { text }
  def _var
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        ( # choice
          match_string("-") ||
          scan(/\G(?i-mx:[a-z][\w-]*)/)
          # end choice
        ) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_var
  end

  # method = < /[a-z_]\w*/i > { text }
  def _method
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        scan(/\G(?i-mx:[a-z_]\w*)/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_method
  end

  # dbl_escapes = ("n" { "\n" } | "s" { " " } | "r" { "\r" } | "t" { "\t" } | "v" { "\v" } | "f" { "\f" } | "b" { "\b" } | "a" { "\a" } | "e" { "\e" } | "\\" { "\\" } | "\"" { "\"" } | num_escapes | < . > { text })
  def _dbl_escapes
    ( # choice
      sequence(self.pos,  # sequence
        match_string("n") &&
        ( @result = ("\n"); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("s") &&
        ( @result = (" "); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("r") &&
        ( @result = ("\r"); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("t") &&
        ( @result = ("\t"); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("v") &&
        ( @result = ("\v"); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("f") &&
        ( @result = ("\f"); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("b") &&
        ( @result = ("\b"); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("a") &&
        ( @result = ("\a"); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("e") &&
        ( @result = ("\e"); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("\\") &&
        ( @result = ("\\"); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("\"") &&
        ( @result = ("\""); true )  # end sequence
      ) ||
      apply(:_num_escapes) ||
      sequence(self.pos,  # sequence
        ( _text_start = self.pos
          get_byte &&
          ( text = get_text(_text_start); true )
        ) &&
        ( @result = (text); true )  # end sequence
      )
      # end choice
    ) or set_failed_rule :_dbl_escapes
  end

  # num_escapes = (< /[0-7]{1,3}/ > { [text.to_i(8)].pack("U") } | "x" < /[a-f\d]{2}/i > { [text.to_i(16)].pack("U") })
  def _num_escapes
    ( # choice
      sequence(self.pos,  # sequence
        ( _text_start = self.pos
          scan(/\G(?-mix:[0-7]{1,3})/) &&
          ( text = get_text(_text_start); true )
        ) &&
        ( @result = ([text.to_i(8)].pack("U")); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("x") &&
        ( _text_start = self.pos
          scan(/\G(?i-mx:[a-f\d]{2})/) &&
          ( text = get_text(_text_start); true )
        ) &&
        ( @result = ([text.to_i(16)].pack("U")); true )  # end sequence
      )
      # end choice
    ) or set_failed_rule :_num_escapes
  end

  # dbl_seq = < /[^\\"]+/ > { text }
  def _dbl_seq
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:[^\\"]+)/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_dbl_seq
  end

  # dbl_not_quote = ("\\" dbl_escapes | dbl_seq)*:ary { Array(ary) }
  def _dbl_not_quote
    sequence(self.pos,  # sequence
      loop_range(0.., true) {
        ( # choice
          sequence(self.pos,  # sequence
            match_string("\\") &&
            apply(:_dbl_escapes)  # end sequence
          ) ||
          apply(:_dbl_seq)
          # end choice
        )
      } &&
      ( ary = @result; true ) &&
      ( @result = (Array(ary)); true )  # end sequence
    ) or set_failed_rule :_dbl_not_quote
  end

  # dbl_string = "\"" dbl_not_quote:s "\"" { @g.str(s.join) }
  def _dbl_string
    sequence(self.pos,  # sequence
      match_string("\"") &&
      apply(:_dbl_not_quote) &&
      ( s = @result; true ) &&
      match_string("\"") &&
      ( @result = (@g.str(s.join)); true )  # end sequence
    ) or set_failed_rule :_dbl_string
  end

  # sgl_escape_quote = "\\'" { "'" }
  def _sgl_escape_quote
    sequence(self.pos,  # sequence
      match_string("\\'") &&
      ( @result = ("'"); true )  # end sequence
    ) or set_failed_rule :_sgl_escape_quote
  end

  # sgl_seq = < /[^']/ > { text }
  def _sgl_seq
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:[^'])/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_sgl_seq
  end

  # sgl_not_quote = (sgl_escape_quote | sgl_seq)*:segs { Array(segs) }
  def _sgl_not_quote
    sequence(self.pos,  # sequence
      loop_range(0.., true) {
        ( # choice
          apply(:_sgl_escape_quote) ||
          apply(:_sgl_seq)
          # end choice
        )
      } &&
      ( segs = @result; true ) &&
      ( @result = (Array(segs)); true )  # end sequence
    ) or set_failed_rule :_sgl_not_quote
  end

  # sgl_string = "'" sgl_not_quote:s "'" { @g.str(s.join) }
  def _sgl_string
    sequence(self.pos,  # sequence
      match_string("'") &&
      apply(:_sgl_not_quote) &&
      ( s = @result; true ) &&
      match_string("'") &&
      ( @result = (@g.str(s.join)); true )  # end sequence
    ) or set_failed_rule :_sgl_string
  end

  # string = (dbl_string | sgl_string)
  def _string
    ( # choice
      apply(:_dbl_string) ||
      apply(:_sgl_string)
      # end choice
    ) or set_failed_rule :_string
  end

  # not_slash = < ("\\/" | /[^\/]/)+ > { text }
  def _not_slash
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        loop_range(1.., false) {
          ( # choice
            match_string("\\/") ||
            scan(/\G(?-mix:[^\/])/)
            # end choice
          )
        } &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_not_slash
  end

  # regexp_opts = < [a-z]* > { text }
  def _regexp_opts
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        while true  # kleene
          sequence(self.pos, (  # char range
            _tmp = get_byte
            _tmp && _tmp >= 97 && _tmp <= 122
          )) || (break true) # end kleene
        end &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_regexp_opts
  end

  # regexp = "/" not_slash:body "/" regexp_opts:opts { @g.reg body, opts }
  def _regexp
    sequence(self.pos,  # sequence
      match_string("/") &&
      apply(:_not_slash) &&
      ( body = @result; true ) &&
      match_string("/") &&
      apply(:_regexp_opts) &&
      ( opts = @result; true ) &&
      ( @result = (@g.reg body, opts); true )  # end sequence
    ) or set_failed_rule :_regexp
  end

  # char = < /[a-z\d]/i > { text }
  def _char
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        scan(/\G(?i-mx:[a-z\d])/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_char
  end

  # char_range = "[" char:l "-" char:r "]" { @g.range(l,r) }
  def _char_range
    sequence(self.pos,  # sequence
      match_string("[") &&
      apply(:_char) &&
      ( l = @result; true ) &&
      match_string("-") &&
      apply(:_char) &&
      ( r = @result; true ) &&
      match_string("]") &&
      ( @result = (@g.range(l,r)); true )  # end sequence
    ) or set_failed_rule :_char_range
  end

  # range_num = < /[1-9]\d*/ > { text }
  def _range_num
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:[1-9]\d*)/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_range_num
  end

  # range_elem = < (range_num | kleene) > { text }
  def _range_elem
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        ( # choice
          apply(:_range_num) ||
          apply(:_kleene)
          # end choice
        ) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_range_elem
  end

  # mult_range = ("[" - range_elem:l - "," - range_elem:r - "]" { [l == "*" ? nil : l.to_i, r == "*" ? nil : r.to_i] } | "[" - range_num:e - "]" { [e.to_i, e.to_i] })
  def _mult_range
    ( # choice
      sequence(self.pos,  # sequence
        match_string("[") &&
        apply(:__hyphen_) &&
        apply(:_range_elem) &&
        ( l = @result; true ) &&
        apply(:__hyphen_) &&
        match_string(",") &&
        apply(:__hyphen_) &&
        apply(:_range_elem) &&
        ( r = @result; true ) &&
        apply(:__hyphen_) &&
        match_string("]") &&
        ( @result = ([l == "*" ? nil : l.to_i, r == "*" ? nil : r.to_i]); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("[") &&
        apply(:__hyphen_) &&
        apply(:_range_num) &&
        ( e = @result; true ) &&
        apply(:__hyphen_) &&
        match_string("]") &&
        ( @result = ([e.to_i, e.to_i]); true )  # end sequence
      )
      # end choice
    ) or set_failed_rule :_mult_range
  end

  # curly_block = curly
  def _curly_block
    apply(:_curly) or set_failed_rule :_curly_block
  end

  # curly = "{" < (spaces | /[^{}"']+/ | string | curly)* > "}" { @g.action(text) }
  def _curly
    sequence(self.pos,  # sequence
      match_string("{") &&
      ( _text_start = self.pos
        while true  # kleene
          ( # choice
            apply(:_spaces) ||
            scan(/\G(?-mix:[^{}"']+)/) ||
            apply(:_string) ||
            apply(:_curly)
            # end choice
          ) || (break true) # end kleene
        end &&
        ( text = get_text(_text_start); true )
      ) &&
      match_string("}") &&
      ( @result = (@g.action(text)); true )  # end sequence
    ) or set_failed_rule :_curly
  end

  # nested_paren = "(" (/[^()"']+/ | string | nested_paren)* ")"
  def _nested_paren
    sequence(self.pos,  # sequence
      match_string("(") &&
      while true  # kleene
        ( # choice
          scan(/\G(?-mix:[^()"']+)/) ||
          apply(:_string) ||
          apply(:_nested_paren)
          # end choice
        ) || (break true) # end kleene
      end &&
      match_string(")")  # end sequence
    ) or set_failed_rule :_nested_paren
  end

  # value = (value:v ":" var:n { @g.t(v,n) } | value:v "?" { @g.maybe(v) } | value:v "+" { @g.many(v) } | value:v "*" { @g.kleene(v) } | value:v mult_range:r { @g.multiple(v, *r) } | "&" value:v { @g.andp(v) } | "!" value:v { @g.notp(v) } | "(" - expression:o - ")" { o } | "@<" - expression:o - ">" { @g.bounds(o) } | "<" - expression:o - ">" { @g.collect(o) } | curly_block | "~" method:m < nested_paren? > { @g.action("#{m}#{text}") } | "." { @g.dot } | "@" var:name < nested_paren? > !(- "=") { @g.invoke(name, text.empty? ? nil : text) } | "^" var:name < nested_paren? > { @g.foreign_invoke("parent", name, text) } | "%" var:gram "." var:name < nested_paren? > { @g.foreign_invoke(gram, name, text) } | var:name < nested_paren? > !(- "=") { @g.ref(name, nil, text.empty? ? nil : text) } | char_range | regexp | string)
  def _value
    ( # choice
      sequence(self.pos,  # sequence
        apply(:_value) &&
        ( v = @result; true ) &&
        match_string(":") &&
        apply(:_var) &&
        ( n = @result; true ) &&
        ( @result = (@g.t(v,n)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:_value) &&
        ( v = @result; true ) &&
        match_string("?") &&
        ( @result = (@g.maybe(v)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:_value) &&
        ( v = @result; true ) &&
        match_string("+") &&
        ( @result = (@g.many(v)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:_value) &&
        ( v = @result; true ) &&
        match_string("*") &&
        ( @result = (@g.kleene(v)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:_value) &&
        ( v = @result; true ) &&
        apply(:_mult_range) &&
        ( r = @result; true ) &&
        ( @result = (@g.multiple(v, *r)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("&") &&
        apply(:_value) &&
        ( v = @result; true ) &&
        ( @result = (@g.andp(v)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("!") &&
        apply(:_value) &&
        ( v = @result; true ) &&
        ( @result = (@g.notp(v)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("(") &&
        apply(:__hyphen_) &&
        apply(:_expression) &&
        ( o = @result; true ) &&
        apply(:__hyphen_) &&
        match_string(")") &&
        ( @result = (o); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("@<") &&
        apply(:__hyphen_) &&
        apply(:_expression) &&
        ( o = @result; true ) &&
        apply(:__hyphen_) &&
        match_string(">") &&
        ( @result = (@g.bounds(o)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("<") &&
        apply(:__hyphen_) &&
        apply(:_expression) &&
        ( o = @result; true ) &&
        apply(:__hyphen_) &&
        match_string(">") &&
        ( @result = (@g.collect(o)); true )  # end sequence
      ) ||
      apply(:_curly_block) ||
      sequence(self.pos,  # sequence
        match_string("~") &&
        apply(:_method) &&
        ( m = @result; true ) &&
        ( _text_start = self.pos
          (  # optional
            apply(:_nested_paren) ||
            true  # end optional
          ) &&
          ( text = get_text(_text_start); true )
        ) &&
        ( @result = (@g.action("#{m}#{text}")); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string(".") &&
        ( @result = (@g.dot); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("@") &&
        apply(:_var) &&
        ( name = @result; true ) &&
        ( _text_start = self.pos
          (  # optional
            apply(:_nested_paren) ||
            true  # end optional
          ) &&
          ( text = get_text(_text_start); true )
        ) &&
        look_negation(self.pos,
          sequence(self.pos,  # sequence
            apply(:__hyphen_) &&
            match_string("=")  # end sequence
          )  # end negation
        ) &&
        ( @result = (@g.invoke(name, text.empty? ? nil : text)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("^") &&
        apply(:_var) &&
        ( name = @result; true ) &&
        ( _text_start = self.pos
          (  # optional
            apply(:_nested_paren) ||
            true  # end optional
          ) &&
          ( text = get_text(_text_start); true )
        ) &&
        ( @result = (@g.foreign_invoke("parent", name, text)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        match_string("%") &&
        apply(:_var) &&
        ( gram = @result; true ) &&
        match_string(".") &&
        apply(:_var) &&
        ( name = @result; true ) &&
        ( _text_start = self.pos
          (  # optional
            apply(:_nested_paren) ||
            true  # end optional
          ) &&
          ( text = get_text(_text_start); true )
        ) &&
        ( @result = (@g.foreign_invoke(gram, name, text)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:_var) &&
        ( name = @result; true ) &&
        ( _text_start = self.pos
          (  # optional
            apply(:_nested_paren) ||
            true  # end optional
          ) &&
          ( text = get_text(_text_start); true )
        ) &&
        look_negation(self.pos,
          sequence(self.pos,  # sequence
            apply(:__hyphen_) &&
            match_string("=")  # end sequence
          )  # end negation
        ) &&
        ( @result = (@g.ref(name, nil, text.empty? ? nil : text)); true )  # end sequence
      ) ||
      apply(:_char_range) ||
      apply(:_regexp) ||
      apply(:_string)
      # end choice
    ) or set_failed_rule :_value
  end

  # spaces = (space | comment)+
  def _spaces
    loop_range(1.., false) {
      ( # choice
        apply(:_space) ||
        apply(:_comment)
        # end choice
      )
    } or set_failed_rule :_spaces
  end

  # values = (values:s spaces value:v { @g.seq(s, v) } | value:l spaces value:r { @g.seq(l, r) } | value)
  def _values
    ( # choice
      sequence(self.pos,  # sequence
        apply(:_values) &&
        ( s = @result; true ) &&
        apply(:_spaces) &&
        apply(:_value) &&
        ( v = @result; true ) &&
        ( @result = (@g.seq(s, v)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:_value) &&
        ( l = @result; true ) &&
        apply(:_spaces) &&
        apply(:_value) &&
        ( r = @result; true ) &&
        ( @result = (@g.seq(l, r)); true )  # end sequence
      ) ||
      apply(:_value)
      # end choice
    ) or set_failed_rule :_values
  end

  # choose_cont = - "|" - values:v { v }
  def _choose_cont
    sequence(self.pos,  # sequence
      apply(:__hyphen_) &&
      match_string("|") &&
      apply(:__hyphen_) &&
      apply(:_values) &&
      ( v = @result; true ) &&
      ( @result = (v); true )  # end sequence
    ) or set_failed_rule :_choose_cont
  end

  # expression = (values:v choose_cont+:alts { @g.any(v, *alts) } | values)
  def _expression
    ( # choice
      sequence(self.pos,  # sequence
        apply(:_values) &&
        ( v = @result; true ) &&
        loop_range(1.., true) {
          apply(:_choose_cont)
        } &&
        ( alts = @result; true ) &&
        ( @result = (@g.any(v, *alts)); true )  # end sequence
      ) ||
      apply(:_values)
      # end choice
    ) or set_failed_rule :_expression
  end

  # args = (args:a "," - var:n - { a + [n] } | - var:n - { [n] })
  def _args
    ( # choice
      sequence(self.pos,  # sequence
        apply(:_args) &&
        ( a = @result; true ) &&
        match_string(",") &&
        apply(:__hyphen_) &&
        apply(:_var) &&
        ( n = @result; true ) &&
        apply(:__hyphen_) &&
        ( @result = (a + [n]); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:__hyphen_) &&
        apply(:_var) &&
        ( n = @result; true ) &&
        apply(:__hyphen_) &&
        ( @result = ([n]); true )  # end sequence
      )
      # end choice
    ) or set_failed_rule :_args
  end

  # statement = (- var:v "(" args:a ")" - "=" - expression:o { @g.set(v, o, a) } | - var:v - "=" - expression:o { @g.set(v, o) } | - "%" var:name - "=" - < /[:\w]+/ > { @g.add_foreign_grammar(name, text) } | - "%%" - curly:act { @g.add_setup act } | - "%%" - var:name - curly:act { @g.add_directive name, act } | - "%%" - var:name - "=" - < (!"\n" .)+ > { @g.set_variable(name, text) })
  def _statement
    ( # choice
      sequence(self.pos,  # sequence
        apply(:__hyphen_) &&
        apply(:_var) &&
        ( v = @result; true ) &&
        match_string("(") &&
        apply(:_args) &&
        ( a = @result; true ) &&
        match_string(")") &&
        apply(:__hyphen_) &&
        match_string("=") &&
        apply(:__hyphen_) &&
        apply(:_expression) &&
        ( o = @result; true ) &&
        ( @result = (@g.set(v, o, a)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:__hyphen_) &&
        apply(:_var) &&
        ( v = @result; true ) &&
        apply(:__hyphen_) &&
        match_string("=") &&
        apply(:__hyphen_) &&
        apply(:_expression) &&
        ( o = @result; true ) &&
        ( @result = (@g.set(v, o)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:__hyphen_) &&
        match_string("%") &&
        apply(:_var) &&
        ( name = @result; true ) &&
        apply(:__hyphen_) &&
        match_string("=") &&
        apply(:__hyphen_) &&
        ( _text_start = self.pos
          scan(/\G(?-mix:[:\w]+)/) &&
          ( text = get_text(_text_start); true )
        ) &&
        ( @result = (@g.add_foreign_grammar(name, text)); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:__hyphen_) &&
        match_string("%%") &&
        apply(:__hyphen_) &&
        apply(:_curly) &&
        ( act = @result; true ) &&
        ( @result = (@g.add_setup act); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:__hyphen_) &&
        match_string("%%") &&
        apply(:__hyphen_) &&
        apply(:_var) &&
        ( name = @result; true ) &&
        apply(:__hyphen_) &&
        apply(:_curly) &&
        ( act = @result; true ) &&
        ( @result = (@g.add_directive name, act); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:__hyphen_) &&
        match_string("%%") &&
        apply(:__hyphen_) &&
        apply(:_var) &&
        ( name = @result; true ) &&
        apply(:__hyphen_) &&
        match_string("=") &&
        apply(:__hyphen_) &&
        ( _text_start = self.pos
          loop_range(1.., false) {
            sequence(self.pos,  # sequence
              look_negation(self.pos,
                match_string("\n")  # end negation
              ) &&
              get_byte  # end sequence
            )
          } &&
          ( text = get_text(_text_start); true )
        ) &&
        ( @result = (@g.set_variable(name, text)); true )  # end sequence
      )
      # end choice
    ) or set_failed_rule :_statement
  end

  # statements = statement (- statements)?
  def _statements
    sequence(self.pos,  # sequence
      apply(:_statement) &&
      (  # optional
        sequence(self.pos,  # sequence
          apply(:__hyphen_) &&
          apply(:_statements)  # end sequence
        ) ||
        true  # end optional
      )  # end sequence
    ) or set_failed_rule :_statements
  end

  # eof = !.
  def _eof
    look_negation(self.pos,
      get_byte  # end negation
    ) or set_failed_rule :_eof
  end

  # root = statements - eof_comment? eof
  def _root
    sequence(self.pos,  # sequence
      apply(:_statements) &&
      apply(:__hyphen_) &&
      (  # optional
        apply(:_eof_comment) ||
        true  # end optional
      ) &&
      apply(:_eof)  # end sequence
    ) or set_failed_rule :_root
  end

  # ast_constant = < /[A-Z]\w*/ > { text }
  def _ast_constant
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:[A-Z]\w*)/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_ast_constant
  end

  # ast_word = < /[a-z_]\w*/i > { text }
  def _ast_word
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        scan(/\G(?i-mx:[a-z_]\w*)/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_ast_word
  end

  # ast_sp = (" " | "\t")*
  def _ast_sp
    while true  # kleene
      ( # choice
        match_string(" ") ||
        match_string("\t")
        # end choice
      ) || (break true) # end kleene
    end or set_failed_rule :_ast_sp
  end

  # ast_words = (ast_words:r ast_sp "," ast_sp ast_word:w { r + [w] } | ast_word:w { [w] })
  def _ast_words
    ( # choice
      sequence(self.pos,  # sequence
        apply(:_ast_words) &&
        ( r = @result; true ) &&
        apply(:_ast_sp) &&
        match_string(",") &&
        apply(:_ast_sp) &&
        apply(:_ast_word) &&
        ( w = @result; true ) &&
        ( @result = (r + [w]); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:_ast_word) &&
        ( w = @result; true ) &&
        ( @result = ([w]); true )  # end sequence
      )
      # end choice
    ) or set_failed_rule :_ast_words
  end

  # ast_root = (ast_constant:c "(" ast_words:w ")" { [c, w] } | ast_constant:c "()"? { [c, []] })
  def _ast_root
    ( # choice
      sequence(self.pos,  # sequence
        apply(:_ast_constant) &&
        ( c = @result; true ) &&
        match_string("(") &&
        apply(:_ast_words) &&
        ( w = @result; true ) &&
        match_string(")") &&
        ( @result = ([c, w]); true )  # end sequence
      ) ||
      sequence(self.pos,  # sequence
        apply(:_ast_constant) &&
        ( c = @result; true ) &&
        (  # optional
          match_string("()") ||
          true  # end optional
        ) &&
        ( @result = ([c, []]); true )  # end sequence
      )
      # end choice
    ) or set_failed_rule :_ast_root
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
