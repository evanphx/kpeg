class TinyMarkdown::Parser
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

    def look_ahead(pos, action)
      @pos = pos
      action ? true : nil
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


  attr_reader :ast

  class Position
    attr_accessor :pos, :line, :col
    def initialize(compiler)
      @pos = compiler.pos
      @line = compiler.current_line
      @col = compiler.current_column
    end
  end

  def position
    Position.new(self)
  end


  # :stopdoc:

  module ::TinyMarkdown
    class Node; end
    class BlockQuoteNode < Node
      def initialize(compiler, position, content)
        @compiler = compiler
        @position = position
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :content
    end
    class BulletListNode < Node
      def initialize(compiler, position, content)
        @compiler = compiler
        @position = position
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :content
    end
    class BulletListItemNode < Node
      def initialize(compiler, position, content)
        @compiler = compiler
        @position = position
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :content
    end
    class DocumentNode < Node
      def initialize(compiler, position, content)
        @compiler = compiler
        @position = position
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :content
    end
    class HeadlineNode < Node
      def initialize(compiler, position, level, content)
        @compiler = compiler
        @position = position
        @level = level
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :level
      attr_reader :content
    end
    class HorizontalRuleNode < Node
      def initialize(compiler, position)
        @compiler = compiler
        @position = position
      end
      attr_reader :compiler
      attr_reader :position
    end
    class InlineElementNode < Node
      def initialize(compiler, position, name, content)
        @compiler = compiler
        @position = position
        @name = name
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :name
      attr_reader :content
    end
    class LineBreakNode < Node
      def initialize(compiler, position)
        @compiler = compiler
        @position = position
      end
      attr_reader :compiler
      attr_reader :position
    end
    class ListNode < Node
      def initialize(compiler, position, content)
        @compiler = compiler
        @position = position
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :content
    end
    class ParaNode < Node
      def initialize(compiler, position, content)
        @compiler = compiler
        @position = position
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :content
    end
    class PlainNode < Node
      def initialize(compiler, position, content)
        @compiler = compiler
        @position = position
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :content
    end
    class TextNode < Node
      def initialize(compiler, position, content)
        @compiler = compiler
        @position = position
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :content
    end
    class VerbatimNode < Node
      def initialize(compiler, position, content)
        @compiler = compiler
        @position = position
        @content = content
      end
      attr_reader :compiler
      attr_reader :position
      attr_reader :content
    end
  end
  module ::TinyMarkdownConstruction
    def block_quote(compiler, position, content)
      ::TinyMarkdown::BlockQuoteNode.new(compiler, position, content)
    end
    def bullet_list(compiler, position, content)
      ::TinyMarkdown::BulletListNode.new(compiler, position, content)
    end
    def bullet_list_item(compiler, position, content)
      ::TinyMarkdown::BulletListItemNode.new(compiler, position, content)
    end
    def document(compiler, position, content)
      ::TinyMarkdown::DocumentNode.new(compiler, position, content)
    end
    def headline(compiler, position, level, content)
      ::TinyMarkdown::HeadlineNode.new(compiler, position, level, content)
    end
    def horizontal_rule(compiler, position)
      ::TinyMarkdown::HorizontalRuleNode.new(compiler, position)
    end
    def inline_element(compiler, position, name, content)
      ::TinyMarkdown::InlineElementNode.new(compiler, position, name, content)
    end
    def linebreak(compiler, position)
      ::TinyMarkdown::LineBreakNode.new(compiler, position)
    end
    def list(compiler, position, content)
      ::TinyMarkdown::ListNode.new(compiler, position, content)
    end
    def para(compiler, position, content)
      ::TinyMarkdown::ParaNode.new(compiler, position, content)
    end
    def plain(compiler, position, content)
      ::TinyMarkdown::PlainNode.new(compiler, position, content)
    end
    def text(compiler, position, content)
      ::TinyMarkdown::TextNode.new(compiler, position, content)
    end
    def verbatim(compiler, position, content)
      ::TinyMarkdown::VerbatimNode.new(compiler, position, content)
    end
  end
  include ::TinyMarkdownConstruction
  def setup_foreign_grammar; end

  # root = Start
  def _root
    apply(:_Start) or set_failed_rule :_root
  end

  # Start = &. Doc:c { @ast = c  }
  def _Start
    ( _save = self.pos  # sequence
      ( _save1 = self.pos
        look_ahead(_save1,
          get_byte  # end look ahead
      )) &&
      apply(:_Doc) &&
      ( c = @result; true ) &&
      ( @result = (@ast = c); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Start
  end

  # Doc = Block*:c {document(self, position, c)}
  def _Doc
    ( _save = self.pos  # sequence
      loop_range(0.., true) {
        apply(:_Block)
      } &&
      ( c = @result; true ) &&
      ( @result = (document(self, position, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Doc
  end

  # Block = BlankLine* (BlockQuote | Verbatim | HorizontalRule | Heading | BulletList | Para | Plain)
  def _Block
    ( _save = self.pos  # sequence
      while true  # kleene
        apply(:_BlankLine) || (break true) # end kleene
      end &&
      ( # choice
        apply(:_BlockQuote) ||
        apply(:_Verbatim) ||
        apply(:_HorizontalRule) ||
        apply(:_Heading) ||
        apply(:_BulletList) ||
        apply(:_Para) ||
        apply(:_Plain)
        # end choice
      ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Block
  end

  # Para = NonindentSpace Inlines:a BlankLine+ {para(self, position, a)}
  def _Para
    ( _save = self.pos  # sequence
      apply(:_NonindentSpace) &&
      apply(:_Inlines) &&
      ( a = @result; true ) &&
      loop_range(1.., false) {
        apply(:_BlankLine)
      } &&
      ( @result = (para(self, position, a)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Para
  end

  # Plain = Inlines:a {plain(self, position, a)}
  def _Plain
    ( _save = self.pos  # sequence
      apply(:_Inlines) &&
      ( a = @result; true ) &&
      ( @result = (plain(self, position, a)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Plain
  end

  # AtxInline = !Newline !(Sp "#"* Sp Newline) Inline:c { c }
  def _AtxInline
    ( _save = self.pos  # sequence
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_Newline)  # end negation
      ))) &&
      ( _save2 = self.pos
        look_ahead(_save2, !(
          ( _save3 = self.pos  # sequence
            apply(:_Sp) &&
            while true  # kleene
              match_string("#") || (break true) # end kleene
            end &&
            apply(:_Sp) &&
            apply(:_Newline) ||
            ( self.pos = _save3; nil )  # end sequence
          )  # end negation
      ))) &&
      apply(:_Inline) &&
      ( c = @result; true ) &&
      ( @result = (c); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_AtxInline
  end

  # AtxStart = < /######|#####|####|###|##|#/ > { text.length }
  def _AtxStart
    ( _save = self.pos  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:######|#####|####|###|##|#)/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text.length); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_AtxStart
  end

  # AtxHeading = AtxStart:level Sp AtxInline+:c (Sp "#"* Sp)? Newline {headline(self, position, level, c)}
  def _AtxHeading
    ( _save = self.pos  # sequence
      apply(:_AtxStart) &&
      ( level = @result; true ) &&
      apply(:_Sp) &&
      loop_range(1.., true) {
        apply(:_AtxInline)
      } &&
      ( c = @result; true ) &&
      ( _save1 = self.pos  # optional
        ( _save2 = self.pos  # sequence
          apply(:_Sp) &&
          while true  # kleene
            match_string("#") || (break true) # end kleene
          end &&
          apply(:_Sp) ||
          ( self.pos = _save2; nil )  # end sequence
        ) ||
        ( self.pos = _save1; true )  # end optional
      ) &&
      apply(:_Newline) &&
      ( @result = (headline(self, position, level, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_AtxHeading
  end

  # Heading = AtxHeading
  def _Heading
    apply(:_AtxHeading) or set_failed_rule :_Heading
  end

  # BlockQuote = BlockQuoteRaw:c {block_quote(self, position, c)}
  def _BlockQuote
    ( _save = self.pos  # sequence
      apply(:_BlockQuoteRaw) &&
      ( c = @result; true ) &&
      ( @result = (block_quote(self, position, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_BlockQuote
  end

  # BlockQuoteRaw = (">" " "? Line:c { c })+:cc { cc }
  def _BlockQuoteRaw
    ( _save = self.pos  # sequence
      loop_range(1.., true) {
        ( _save1 = self.pos  # sequence
          match_string(">") &&
          ( _save2 = self.pos  # optional
            match_string(" ") ||
            ( self.pos = _save2; true )  # end optional
          ) &&
          apply(:_Line) &&
          ( c = @result; true ) &&
          ( @result = (c); true ) ||
          ( self.pos = _save1; nil )  # end sequence
        )
      } &&
      ( cc = @result; true ) &&
      ( @result = (cc); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_BlockQuoteRaw
  end

  # NonblankIndentedLine = !BlankLine IndentedLine:c { c }
  def _NonblankIndentedLine
    ( _save = self.pos  # sequence
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_BlankLine)  # end negation
      ))) &&
      apply(:_IndentedLine) &&
      ( c = @result; true ) &&
      ( @result = (c); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_NonblankIndentedLine
  end

  # VerbatimChunk = (BlankLine { text(self,position,"\n") })*:c1 (NonblankIndentedLine:c { [c, text(self,position,"\n")] })+:c2 { c1 + c2.flatten }
  def _VerbatimChunk
    ( _save = self.pos  # sequence
      loop_range(0.., true) {
        ( _save1 = self.pos  # sequence
          apply(:_BlankLine) &&
          ( @result = (text(self,position,"\n")); true ) ||
          ( self.pos = _save1; nil )  # end sequence
        )
      } &&
      ( c1 = @result; true ) &&
      loop_range(1.., true) {
        ( _save2 = self.pos  # sequence
          apply(:_NonblankIndentedLine) &&
          ( c = @result; true ) &&
          ( @result = ([c, text(self,position,"\n")]); true ) ||
          ( self.pos = _save2; nil )  # end sequence
        )
      } &&
      ( c2 = @result; true ) &&
      ( @result = (c1 + c2.flatten); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_VerbatimChunk
  end

  # Verbatim = VerbatimChunk+:cc {verbatim(self, position, cc.flatten)}
  def _Verbatim
    ( _save = self.pos  # sequence
      loop_range(1.., true) {
        apply(:_VerbatimChunk)
      } &&
      ( cc = @result; true ) &&
      ( @result = (verbatim(self, position, cc.flatten)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Verbatim
  end

  # HorizontalRule = NonindentSpace ("*" Sp "*" Sp "*" (Sp "*")* | "-" Sp "-" Sp "-" (Sp "-")* | "_" Sp "_" Sp "_" (Sp "_")*) Sp Newline BlankLine+ {horizontal_rule(self, position)}
  def _HorizontalRule
    ( _save = self.pos  # sequence
      apply(:_NonindentSpace) &&
      ( # choice
        ( _save1 = self.pos  # sequence
          match_string("*") &&
          apply(:_Sp) &&
          match_string("*") &&
          apply(:_Sp) &&
          match_string("*") &&
          while true  # kleene
            ( _save2 = self.pos  # sequence
              apply(:_Sp) &&
              match_string("*") ||
              ( self.pos = _save2; nil )  # end sequence
            ) || (break true) # end kleene
          end ||
          ( self.pos = _save1; nil )  # end sequence
        ) ||
        ( _save3 = self.pos  # sequence
          match_string("-") &&
          apply(:_Sp) &&
          match_string("-") &&
          apply(:_Sp) &&
          match_string("-") &&
          while true  # kleene
            ( _save4 = self.pos  # sequence
              apply(:_Sp) &&
              match_string("-") ||
              ( self.pos = _save4; nil )  # end sequence
            ) || (break true) # end kleene
          end ||
          ( self.pos = _save3; nil )  # end sequence
        ) ||
        ( _save5 = self.pos  # sequence
          match_string("_") &&
          apply(:_Sp) &&
          match_string("_") &&
          apply(:_Sp) &&
          match_string("_") &&
          while true  # kleene
            ( _save6 = self.pos  # sequence
              apply(:_Sp) &&
              match_string("_") ||
              ( self.pos = _save6; nil )  # end sequence
            ) || (break true) # end kleene
          end ||
          ( self.pos = _save5; nil )  # end sequence
        )
        # end choice
      ) &&
      apply(:_Sp) &&
      apply(:_Newline) &&
      loop_range(1.., false) {
        apply(:_BlankLine)
      } &&
      ( @result = (horizontal_rule(self, position)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_HorizontalRule
  end

  # Bullet = !HorizontalRule NonindentSpace ("+" | "*" | "-") Spacechar+
  def _Bullet
    ( _save = self.pos  # sequence
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_HorizontalRule)  # end negation
      ))) &&
      apply(:_NonindentSpace) &&
      ( # choice
        match_string("+") ||
        match_string("*") ||
        match_string("-")
        # end choice
      ) &&
      loop_range(1.., false) {
        apply(:_Spacechar)
      } ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Bullet
  end

  # BulletList = &Bullet ListTight:c {bullet_list(self, position, c)}
  def _BulletList
    ( _save = self.pos  # sequence
      ( _save1 = self.pos
        look_ahead(_save1,
          apply(:_Bullet)  # end look ahead
      )) &&
      apply(:_ListTight) &&
      ( c = @result; true ) &&
      ( @result = (bullet_list(self, position, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_BulletList
  end

  # ListTight = ListItemTight+:cc BlankLine* !Bullet { cc }
  def _ListTight
    ( _save = self.pos  # sequence
      loop_range(1.., true) {
        apply(:_ListItemTight)
      } &&
      ( cc = @result; true ) &&
      while true  # kleene
        apply(:_BlankLine) || (break true) # end kleene
      end &&
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_Bullet)  # end negation
      ))) &&
      ( @result = (cc); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_ListTight
  end

  # ListItemTight = Bullet ListBlock:c {bullet_list_item(self, position, c)}
  def _ListItemTight
    ( _save = self.pos  # sequence
      apply(:_Bullet) &&
      apply(:_ListBlock) &&
      ( c = @result; true ) &&
      ( @result = (bullet_list_item(self, position, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_ListItemTight
  end

  # ListBlock = !BlankLine Line:c ListBlockLine*:cc { cc.unshift(c) }
  def _ListBlock
    ( _save = self.pos  # sequence
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_BlankLine)  # end negation
      ))) &&
      apply(:_Line) &&
      ( c = @result; true ) &&
      loop_range(0.., true) {
        apply(:_ListBlockLine)
      } &&
      ( cc = @result; true ) &&
      ( @result = (cc.unshift(c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_ListBlock
  end

  # ListBlockLine = !BlankLine !(Indent? Bullet) !HorizontalRule OptionallyIndentedLine
  def _ListBlockLine
    ( _save = self.pos  # sequence
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_BlankLine)  # end negation
      ))) &&
      ( _save2 = self.pos
        look_ahead(_save2, !(
          ( _save3 = self.pos  # sequence
            ( _save4 = self.pos  # optional
              apply(:_Indent) ||
              ( self.pos = _save4; true )  # end optional
            ) &&
            apply(:_Bullet) ||
            ( self.pos = _save3; nil )  # end sequence
          )  # end negation
      ))) &&
      ( _save5 = self.pos
        look_ahead(_save5, !(
          apply(:_HorizontalRule)  # end negation
      ))) &&
      apply(:_OptionallyIndentedLine) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_ListBlockLine
  end

  # Inlines = (!Endline Inline:c { c } | Endline:c &Inline { c })+:cc Endline? { cc }
  def _Inlines
    ( _save = self.pos  # sequence
      loop_range(1.., true) {
        ( # choice
          ( _save1 = self.pos  # sequence
            ( _save2 = self.pos
              look_ahead(_save2, !(
                apply(:_Endline)  # end negation
            ))) &&
            apply(:_Inline) &&
            ( c = @result; true ) &&
            ( @result = (c); true ) ||
            ( self.pos = _save1; nil )  # end sequence
          ) ||
          ( _save3 = self.pos  # sequence
            apply(:_Endline) &&
            ( c = @result; true ) &&
            ( _save4 = self.pos
              look_ahead(_save4,
                apply(:_Inline)  # end look ahead
            )) &&
            ( @result = (c); true ) ||
            ( self.pos = _save3; nil )  # end sequence
          )
          # end choice
        )
      } &&
      ( cc = @result; true ) &&
      ( _save5 = self.pos  # optional
        apply(:_Endline) ||
        ( self.pos = _save5; true )  # end optional
      ) &&
      ( @result = (cc); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Inlines
  end

  # Inline = (Str | Endline | Space | Strong | Emph | Code | Symbol)
  def _Inline
    ( # choice
      apply(:_Str) ||
      apply(:_Endline) ||
      apply(:_Space) ||
      apply(:_Strong) ||
      apply(:_Emph) ||
      apply(:_Code) ||
      apply(:_Symbol)
      # end choice
    ) or set_failed_rule :_Inline
  end

  # Space = Spacechar+:c {text(self, position, c.join(""))}
  def _Space
    ( _save = self.pos  # sequence
      loop_range(1.., true) {
        apply(:_Spacechar)
      } &&
      ( c = @result; true ) &&
      ( @result = (text(self, position, c.join(""))); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Space
  end

  # Str = NormalChar+:c1 StrChunk*:c2 {text(self, position, (c1+c2).join(""))}
  def _Str
    ( _save = self.pos  # sequence
      loop_range(1.., true) {
        apply(:_NormalChar)
      } &&
      ( c1 = @result; true ) &&
      loop_range(0.., true) {
        apply(:_StrChunk)
      } &&
      ( c2 = @result; true ) &&
      ( @result = (text(self, position, (c1+c2).join(""))); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Str
  end

  # StrChunk = (NormalChar:c { [c] } | "_"+:c1 NormalChar:c2 { c1.push(c2) })+:cc { cc.flatten }
  def _StrChunk
    ( _save = self.pos  # sequence
      loop_range(1.., true) {
        ( # choice
          ( _save1 = self.pos  # sequence
            apply(:_NormalChar) &&
            ( c = @result; true ) &&
            ( @result = ([c]); true ) ||
            ( self.pos = _save1; nil )  # end sequence
          ) ||
          ( _save2 = self.pos  # sequence
            loop_range(1.., true) {
              match_string("_")
            } &&
            ( c1 = @result; true ) &&
            apply(:_NormalChar) &&
            ( c2 = @result; true ) &&
            ( @result = (c1.push(c2)); true ) ||
            ( self.pos = _save2; nil )  # end sequence
          )
          # end choice
        )
      } &&
      ( cc = @result; true ) &&
      ( @result = (cc.flatten); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_StrChunk
  end

  # Endline = (LineBreak | TerminalEndline | NormalEndline)
  def _Endline
    ( # choice
      apply(:_LineBreak) ||
      apply(:_TerminalEndline) ||
      apply(:_NormalEndline)
      # end choice
    ) or set_failed_rule :_Endline
  end

  # NormalEndline = Sp Newline !BlankLine !">" !AtxStart !(Line ("="+ | "-"+) Newline) {text(self, position, "\n")}
  def _NormalEndline
    ( _save = self.pos  # sequence
      apply(:_Sp) &&
      apply(:_Newline) &&
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_BlankLine)  # end negation
      ))) &&
      ( _save2 = self.pos
        look_ahead(_save2, !(
          match_string(">")  # end negation
      ))) &&
      ( _save3 = self.pos
        look_ahead(_save3, !(
          apply(:_AtxStart)  # end negation
      ))) &&
      ( _save4 = self.pos
        look_ahead(_save4, !(
          ( _save5 = self.pos  # sequence
            apply(:_Line) &&
            ( # choice
              loop_range(1.., false) {
                match_string("=")
              } ||
              loop_range(1.., false) {
                match_string("-")
              }
              # end choice
            ) &&
            apply(:_Newline) ||
            ( self.pos = _save5; nil )  # end sequence
          )  # end negation
      ))) &&
      ( @result = (text(self, position, "\n")); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_NormalEndline
  end

  # TerminalEndline = Sp Newline Eof {text(self, position, "\n")}
  def _TerminalEndline
    ( _save = self.pos  # sequence
      apply(:_Sp) &&
      apply(:_Newline) &&
      apply(:_Eof) &&
      ( @result = (text(self, position, "\n")); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_TerminalEndline
  end

  # LineBreak = "  " NormalEndline {linebreak(self, position)}
  def _LineBreak
    ( _save = self.pos  # sequence
      match_string("  ") &&
      apply(:_NormalEndline) &&
      ( @result = (linebreak(self, position)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_LineBreak
  end

  # Symbol = SpecialChar:c {text(self, position, c)}
  def _Symbol
    ( _save = self.pos  # sequence
      apply(:_SpecialChar) &&
      ( c = @result; true ) &&
      ( @result = (text(self, position, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Symbol
  end

  # Emph = (EmphStar | EmphUl)
  def _Emph
    ( # choice
      apply(:_EmphStar) ||
      apply(:_EmphUl)
      # end choice
    ) or set_failed_rule :_Emph
  end

  # Whitespace = (Spacechar | Newline)
  def _Whitespace
    ( # choice
      apply(:_Spacechar) ||
      apply(:_Newline)
      # end choice
    ) or set_failed_rule :_Whitespace
  end

  # EmphStar = "*" !Whitespace (!"*" Inline:b { b } | StrongStar:b { b })+:c "*" {inline_element(self, position, :em, c)}
  def _EmphStar
    ( _save = self.pos  # sequence
      match_string("*") &&
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_Whitespace)  # end negation
      ))) &&
      loop_range(1.., true) {
        ( # choice
          ( _save2 = self.pos  # sequence
            ( _save3 = self.pos
              look_ahead(_save3, !(
                match_string("*")  # end negation
            ))) &&
            apply(:_Inline) &&
            ( b = @result; true ) &&
            ( @result = (b); true ) ||
            ( self.pos = _save2; nil )  # end sequence
          ) ||
          ( _save4 = self.pos  # sequence
            apply(:_StrongStar) &&
            ( b = @result; true ) &&
            ( @result = (b); true ) ||
            ( self.pos = _save4; nil )  # end sequence
          )
          # end choice
        )
      } &&
      ( c = @result; true ) &&
      match_string("*") &&
      ( @result = (inline_element(self, position, :em, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_EmphStar
  end

  # EmphUl = "_" !Whitespace (!"_" Inline:b { b } | StrongUl:b { b })+:c "_" {inline_element(self, position, :em, c)}
  def _EmphUl
    ( _save = self.pos  # sequence
      match_string("_") &&
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_Whitespace)  # end negation
      ))) &&
      loop_range(1.., true) {
        ( # choice
          ( _save2 = self.pos  # sequence
            ( _save3 = self.pos
              look_ahead(_save3, !(
                match_string("_")  # end negation
            ))) &&
            apply(:_Inline) &&
            ( b = @result; true ) &&
            ( @result = (b); true ) ||
            ( self.pos = _save2; nil )  # end sequence
          ) ||
          ( _save4 = self.pos  # sequence
            apply(:_StrongUl) &&
            ( b = @result; true ) &&
            ( @result = (b); true ) ||
            ( self.pos = _save4; nil )  # end sequence
          )
          # end choice
        )
      } &&
      ( c = @result; true ) &&
      match_string("_") &&
      ( @result = (inline_element(self, position, :em, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_EmphUl
  end

  # Strong = (StrongStar | StrongUl)
  def _Strong
    ( # choice
      apply(:_StrongStar) ||
      apply(:_StrongUl)
      # end choice
    ) or set_failed_rule :_Strong
  end

  # StrongStar = "**" !Whitespace (!"**" Inline:b { b })+:c "**" {inline_element(self, position, :strong, c)}
  def _StrongStar
    ( _save = self.pos  # sequence
      match_string("**") &&
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_Whitespace)  # end negation
      ))) &&
      loop_range(1.., true) {
        ( _save2 = self.pos  # sequence
          ( _save3 = self.pos
            look_ahead(_save3, !(
              match_string("**")  # end negation
          ))) &&
          apply(:_Inline) &&
          ( b = @result; true ) &&
          ( @result = (b); true ) ||
          ( self.pos = _save2; nil )  # end sequence
        )
      } &&
      ( c = @result; true ) &&
      match_string("**") &&
      ( @result = (inline_element(self, position, :strong, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_StrongStar
  end

  # StrongUl = "__" !Whitespace (!"__" Inline:b { b })+:c "__" {inline_element(self, position, :strong, c)}
  def _StrongUl
    ( _save = self.pos  # sequence
      match_string("__") &&
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_Whitespace)  # end negation
      ))) &&
      loop_range(1.., true) {
        ( _save2 = self.pos  # sequence
          ( _save3 = self.pos
            look_ahead(_save3, !(
              match_string("__")  # end negation
          ))) &&
          apply(:_Inline) &&
          ( b = @result; true ) &&
          ( @result = (b); true ) ||
          ( self.pos = _save2; nil )  # end sequence
        )
      } &&
      ( c = @result; true ) &&
      match_string("__") &&
      ( @result = (inline_element(self, position, :strong, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_StrongUl
  end

  # Ticks1 = < /`/ > !"`" { text }
  def _Ticks1
    ( _save = self.pos  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:`)/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( _save1 = self.pos
        look_ahead(_save1, !(
          match_string("`")  # end negation
      ))) &&
      ( @result = (text); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Ticks1
  end

  # Ticks2 = < /``/ > !"`" { text }
  def _Ticks2
    ( _save = self.pos  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:``)/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( _save1 = self.pos
        look_ahead(_save1, !(
          match_string("`")  # end negation
      ))) &&
      ( @result = (text); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Ticks2
  end

  # Code = (Ticks1 Sp (!"`" Nonspacechar)+:c Sp Ticks1 {text(self, position, c.join(""))} | Ticks2 Sp (!"``" Nonspacechar)+:c Sp Ticks2 {text(self, position, c.join(""))}):cc {inline_element(self, position, :code, [cc])}
  def _Code
    ( _save = self.pos  # sequence
      ( # choice
        ( _save1 = self.pos  # sequence
          apply(:_Ticks1) &&
          apply(:_Sp) &&
          loop_range(1.., true) {
            ( _save2 = self.pos  # sequence
              ( _save3 = self.pos
                look_ahead(_save3, !(
                  match_string("`")  # end negation
              ))) &&
              apply(:_Nonspacechar) ||
              ( self.pos = _save2; nil )  # end sequence
            )
          } &&
          ( c = @result; true ) &&
          apply(:_Sp) &&
          apply(:_Ticks1) &&
          ( @result = (text(self, position, c.join(""))); true ) ||
          ( self.pos = _save1; nil )  # end sequence
        ) ||
        ( _save4 = self.pos  # sequence
          apply(:_Ticks2) &&
          apply(:_Sp) &&
          loop_range(1.., true) {
            ( _save5 = self.pos  # sequence
              ( _save6 = self.pos
                look_ahead(_save6, !(
                  match_string("``")  # end negation
              ))) &&
              apply(:_Nonspacechar) ||
              ( self.pos = _save5; nil )  # end sequence
            )
          } &&
          ( c = @result; true ) &&
          apply(:_Sp) &&
          apply(:_Ticks2) &&
          ( @result = (text(self, position, c.join(""))); true ) ||
          ( self.pos = _save4; nil )  # end sequence
        )
        # end choice
      ) &&
      ( cc = @result; true ) &&
      ( @result = (inline_element(self, position, :code, [cc])); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Code
  end

  # BlankLine = Sp Newline
  def _BlankLine
    ( _save = self.pos  # sequence
      apply(:_Sp) &&
      apply(:_Newline) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_BlankLine
  end

  # Quoted = ("\"" (!"\"" .)* "\"" | "'" (!"'" .)* "'")
  def _Quoted
    ( # choice
      ( _save = self.pos  # sequence
        match_string("\"") &&
        while true  # kleene
          ( _save1 = self.pos  # sequence
            ( _save2 = self.pos
              look_ahead(_save2, !(
                match_string("\"")  # end negation
            ))) &&
            get_byte ||
            ( self.pos = _save1; nil )  # end sequence
          ) || (break true) # end kleene
        end &&
        match_string("\"") ||
        ( self.pos = _save; nil )  # end sequence
      ) ||
      ( _save3 = self.pos  # sequence
        match_string("'") &&
        while true  # kleene
          ( _save4 = self.pos  # sequence
            ( _save5 = self.pos
              look_ahead(_save5, !(
                match_string("'")  # end negation
            ))) &&
            get_byte ||
            ( self.pos = _save4; nil )  # end sequence
          ) || (break true) # end kleene
        end &&
        match_string("'") ||
        ( self.pos = _save3; nil )  # end sequence
      )
      # end choice
    ) or set_failed_rule :_Quoted
  end

  # Eof = !.
  def _Eof
    ( _save = self.pos
      look_ahead(_save, !(
        get_byte  # end negation
    ))) or set_failed_rule :_Eof
  end

  # Spacechar = < / |\t/ > { text }
  def _Spacechar
    ( _save = self.pos  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix: |\t)/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Spacechar
  end

  # Nonspacechar = !Spacechar !Newline < . > { text }
  def _Nonspacechar
    ( _save = self.pos  # sequence
      ( _save1 = self.pos
        look_ahead(_save1, !(
          apply(:_Spacechar)  # end negation
      ))) &&
      ( _save2 = self.pos
        look_ahead(_save2, !(
          apply(:_Newline)  # end negation
      ))) &&
      ( _text_start = self.pos
        get_byte &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Nonspacechar
  end

  # Newline = ("\n" | "\r" "\n"?)
  def _Newline
    ( # choice
      match_string("\n") ||
      ( _save = self.pos  # sequence
        match_string("\r") &&
        ( _save1 = self.pos  # optional
          match_string("\n") ||
          ( self.pos = _save1; true )  # end optional
        ) ||
        ( self.pos = _save; nil )  # end sequence
      )
      # end choice
    ) or set_failed_rule :_Newline
  end

  # Sp = Spacechar*
  def _Sp
    while true  # kleene
      apply(:_Spacechar) || (break true) # end kleene
    end or set_failed_rule :_Sp
  end

  # Spnl = Sp (Newline Sp)?
  def _Spnl
    ( _save = self.pos  # sequence
      apply(:_Sp) &&
      ( _save1 = self.pos  # optional
        ( _save2 = self.pos  # sequence
          apply(:_Newline) &&
          apply(:_Sp) ||
          ( self.pos = _save2; nil )  # end sequence
        ) ||
        ( self.pos = _save1; true )  # end optional
      ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Spnl
  end

  # SpecialChar = < /[~*_`&\[\]()<!#\\'"]/ > { text }
  def _SpecialChar
    ( _save = self.pos  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:[~*_`&\[\]()<!#\\'"])/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_SpecialChar
  end

  # NormalChar = !(SpecialChar | Spacechar | Newline) < . > { text }
  def _NormalChar
    ( _save = self.pos  # sequence
      ( _save1 = self.pos
        look_ahead(_save1, !(
          ( # choice
            apply(:_SpecialChar) ||
            apply(:_Spacechar) ||
            apply(:_Newline)
            # end choice
          )  # end negation
      ))) &&
      ( _text_start = self.pos
        get_byte &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_NormalChar
  end

  # AlphanumericAscii = < /[A-Za-z0-9]/ > { text }
  def _AlphanumericAscii
    ( _save = self.pos  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:[A-Za-z0-9])/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_AlphanumericAscii
  end

  # Digit = < /[0-9]/ > { text }
  def _Digit
    ( _save = self.pos  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:[0-9])/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Digit
  end

  # NonindentSpace = < /   |  | |/ > { text }
  def _NonindentSpace
    ( _save = self.pos  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:   |  | |)/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_NonindentSpace
  end

  # Indent = < /\t|    / > { text }
  def _Indent
    ( _save = self.pos  # sequence
      ( _text_start = self.pos
        scan(/\G(?-mix:\t|    )/) &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Indent
  end

  # IndentedLine = Indent Line:c { c }
  def _IndentedLine
    ( _save = self.pos  # sequence
      apply(:_Indent) &&
      apply(:_Line) &&
      ( c = @result; true ) &&
      ( @result = (c); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_IndentedLine
  end

  # OptionallyIndentedLine = Indent? Line
  def _OptionallyIndentedLine
    ( _save = self.pos  # sequence
      ( _save1 = self.pos  # optional
        apply(:_Indent) ||
        ( self.pos = _save1; true )  # end optional
      ) &&
      apply(:_Line) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_OptionallyIndentedLine
  end

  # Line = RawLine:c { c }
  def _Line
    ( _save = self.pos  # sequence
      apply(:_RawLine) &&
      ( c = @result; true ) &&
      ( @result = (c); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_Line
  end

  # RawLine = (< /[^\r\n]*/ > Newline { text } | < /.+/ > Eof { text }):c {text(self, position, c)}
  def _RawLine
    ( _save = self.pos  # sequence
      ( # choice
        ( _save1 = self.pos  # sequence
          ( _text_start = self.pos
            scan(/\G(?-mix:[^\r\n]*)/) &&
            ( text = get_text(_text_start); true )
          ) &&
          apply(:_Newline) &&
          ( @result = (text); true ) ||
          ( self.pos = _save1; nil )  # end sequence
        ) ||
        ( _save2 = self.pos  # sequence
          ( _text_start = self.pos
            scan(/\G(?-mix:.+)/) &&
            ( text = get_text(_text_start); true )
          ) &&
          apply(:_Eof) &&
          ( @result = (text); true ) ||
          ( self.pos = _save2; nil )  # end sequence
        )
        # end choice
      ) &&
      ( c = @result; true ) &&
      ( @result = (text(self, position, c)); true ) ||
      ( self.pos = _save; nil )  # end sequence
    ) or set_failed_rule :_RawLine
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "Start")
  Rules[:_Start] = rule_info("Start", "&. Doc:c { @ast = c  }")
  Rules[:_Doc] = rule_info("Doc", "Block*:c {document(self, position, c)}")
  Rules[:_Block] = rule_info("Block", "BlankLine* (BlockQuote | Verbatim | HorizontalRule | Heading | BulletList | Para | Plain)")
  Rules[:_Para] = rule_info("Para", "NonindentSpace Inlines:a BlankLine+ {para(self, position, a)}")
  Rules[:_Plain] = rule_info("Plain", "Inlines:a {plain(self, position, a)}")
  Rules[:_AtxInline] = rule_info("AtxInline", "!Newline !(Sp \"\#\"* Sp Newline) Inline:c { c }")
  Rules[:_AtxStart] = rule_info("AtxStart", "< /\#\#\#\#\#\#|\#\#\#\#\#|\#\#\#\#|\#\#\#|\#\#|\#/ > { text.length }")
  Rules[:_AtxHeading] = rule_info("AtxHeading", "AtxStart:level Sp AtxInline+:c (Sp \"\#\"* Sp)? Newline {headline(self, position, level, c)}")
  Rules[:_Heading] = rule_info("Heading", "AtxHeading")
  Rules[:_BlockQuote] = rule_info("BlockQuote", "BlockQuoteRaw:c {block_quote(self, position, c)}")
  Rules[:_BlockQuoteRaw] = rule_info("BlockQuoteRaw", "(\">\" \" \"? Line:c { c })+:cc { cc }")
  Rules[:_NonblankIndentedLine] = rule_info("NonblankIndentedLine", "!BlankLine IndentedLine:c { c }")
  Rules[:_VerbatimChunk] = rule_info("VerbatimChunk", "(BlankLine { text(self,position,\"\\n\") })*:c1 (NonblankIndentedLine:c { [c, text(self,position,\"\\n\")] })+:c2 { c1 + c2.flatten }")
  Rules[:_Verbatim] = rule_info("Verbatim", "VerbatimChunk+:cc {verbatim(self, position, cc.flatten)}")
  Rules[:_HorizontalRule] = rule_info("HorizontalRule", "NonindentSpace (\"*\" Sp \"*\" Sp \"*\" (Sp \"*\")* | \"-\" Sp \"-\" Sp \"-\" (Sp \"-\")* | \"_\" Sp \"_\" Sp \"_\" (Sp \"_\")*) Sp Newline BlankLine+ {horizontal_rule(self, position)}")
  Rules[:_Bullet] = rule_info("Bullet", "!HorizontalRule NonindentSpace (\"+\" | \"*\" | \"-\") Spacechar+")
  Rules[:_BulletList] = rule_info("BulletList", "&Bullet ListTight:c {bullet_list(self, position, c)}")
  Rules[:_ListTight] = rule_info("ListTight", "ListItemTight+:cc BlankLine* !Bullet { cc }")
  Rules[:_ListItemTight] = rule_info("ListItemTight", "Bullet ListBlock:c {bullet_list_item(self, position, c)}")
  Rules[:_ListBlock] = rule_info("ListBlock", "!BlankLine Line:c ListBlockLine*:cc { cc.unshift(c) }")
  Rules[:_ListBlockLine] = rule_info("ListBlockLine", "!BlankLine !(Indent? Bullet) !HorizontalRule OptionallyIndentedLine")
  Rules[:_Inlines] = rule_info("Inlines", "(!Endline Inline:c { c } | Endline:c &Inline { c })+:cc Endline? { cc }")
  Rules[:_Inline] = rule_info("Inline", "(Str | Endline | Space | Strong | Emph | Code | Symbol)")
  Rules[:_Space] = rule_info("Space", "Spacechar+:c {text(self, position, c.join(\"\"))}")
  Rules[:_Str] = rule_info("Str", "NormalChar+:c1 StrChunk*:c2 {text(self, position, (c1+c2).join(\"\"))}")
  Rules[:_StrChunk] = rule_info("StrChunk", "(NormalChar:c { [c] } | \"_\"+:c1 NormalChar:c2 { c1.push(c2) })+:cc { cc.flatten }")
  Rules[:_Endline] = rule_info("Endline", "(LineBreak | TerminalEndline | NormalEndline)")
  Rules[:_NormalEndline] = rule_info("NormalEndline", "Sp Newline !BlankLine !\">\" !AtxStart !(Line (\"=\"+ | \"-\"+) Newline) {text(self, position, \"\\n\")}")
  Rules[:_TerminalEndline] = rule_info("TerminalEndline", "Sp Newline Eof {text(self, position, \"\\n\")}")
  Rules[:_LineBreak] = rule_info("LineBreak", "\"  \" NormalEndline {linebreak(self, position)}")
  Rules[:_Symbol] = rule_info("Symbol", "SpecialChar:c {text(self, position, c)}")
  Rules[:_Emph] = rule_info("Emph", "(EmphStar | EmphUl)")
  Rules[:_Whitespace] = rule_info("Whitespace", "(Spacechar | Newline)")
  Rules[:_EmphStar] = rule_info("EmphStar", "\"*\" !Whitespace (!\"*\" Inline:b { b } | StrongStar:b { b })+:c \"*\" {inline_element(self, position, :em, c)}")
  Rules[:_EmphUl] = rule_info("EmphUl", "\"_\" !Whitespace (!\"_\" Inline:b { b } | StrongUl:b { b })+:c \"_\" {inline_element(self, position, :em, c)}")
  Rules[:_Strong] = rule_info("Strong", "(StrongStar | StrongUl)")
  Rules[:_StrongStar] = rule_info("StrongStar", "\"**\" !Whitespace (!\"**\" Inline:b { b })+:c \"**\" {inline_element(self, position, :strong, c)}")
  Rules[:_StrongUl] = rule_info("StrongUl", "\"__\" !Whitespace (!\"__\" Inline:b { b })+:c \"__\" {inline_element(self, position, :strong, c)}")
  Rules[:_Ticks1] = rule_info("Ticks1", "< /`/ > !\"`\" { text }")
  Rules[:_Ticks2] = rule_info("Ticks2", "< /``/ > !\"`\" { text }")
  Rules[:_Code] = rule_info("Code", "(Ticks1 Sp (!\"`\" Nonspacechar)+:c Sp Ticks1 {text(self, position, c.join(\"\"))} | Ticks2 Sp (!\"``\" Nonspacechar)+:c Sp Ticks2 {text(self, position, c.join(\"\"))}):cc {inline_element(self, position, :code, [cc])}")
  Rules[:_BlankLine] = rule_info("BlankLine", "Sp Newline")
  Rules[:_Quoted] = rule_info("Quoted", "(\"\\\"\" (!\"\\\"\" .)* \"\\\"\" | \"'\" (!\"'\" .)* \"'\")")
  Rules[:_Eof] = rule_info("Eof", "!.")
  Rules[:_Spacechar] = rule_info("Spacechar", "< / |\\t/ > { text }")
  Rules[:_Nonspacechar] = rule_info("Nonspacechar", "!Spacechar !Newline < . > { text }")
  Rules[:_Newline] = rule_info("Newline", "(\"\\n\" | \"\\r\" \"\\n\"?)")
  Rules[:_Sp] = rule_info("Sp", "Spacechar*")
  Rules[:_Spnl] = rule_info("Spnl", "Sp (Newline Sp)?")
  Rules[:_SpecialChar] = rule_info("SpecialChar", "< /[~*_`&\\[\\]()<!\#\\\\'\"]/ > { text }")
  Rules[:_NormalChar] = rule_info("NormalChar", "!(SpecialChar | Spacechar | Newline) < . > { text }")
  Rules[:_AlphanumericAscii] = rule_info("AlphanumericAscii", "< /[A-Za-z0-9]/ > { text }")
  Rules[:_Digit] = rule_info("Digit", "< /[0-9]/ > { text }")
  Rules[:_NonindentSpace] = rule_info("NonindentSpace", "< /   |  | |/ > { text }")
  Rules[:_Indent] = rule_info("Indent", "< /\\t|    / > { text }")
  Rules[:_IndentedLine] = rule_info("IndentedLine", "Indent Line:c { c }")
  Rules[:_OptionallyIndentedLine] = rule_info("OptionallyIndentedLine", "Indent? Line")
  Rules[:_Line] = rule_info("Line", "RawLine:c { c }")
  Rules[:_RawLine] = rule_info("RawLine", "(< /[^\\r\\n]*/ > Newline { text } | < /.+/ > Eof { text }):c {text(self, position, c)}")
  # :startdoc:
end
