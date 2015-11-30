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

      setup_foreign_grammar
    end

    attr_reader :string
    attr_reader :failing_rule_offset
    attr_accessor :result, :pos

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



    def get_text(start)
      @string[start..@pos-1]
    end

    # Sets the string and current parsing position for the parser.
    def set_string string, pos
      @string = string
      @string_size = string ? string.size : 0
      @pos = pos
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

        return ans
      end
    end

    def apply(rule)
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

        return ans
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
    _tmp = apply(:_Start)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  # Start = &. Doc:c { @ast = c  }
  def _Start

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = get_byte
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Doc)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @ast = c  ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Start unless _tmp
    return _tmp
  end

  # Doc = Block*:c {document(self, position, c)}
  def _Doc

    _save = self.pos
    while true # sequence
      _ary = []
      while true
        _tmp = apply(:_Block)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; document(self, position, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Doc unless _tmp
    return _tmp
  end

  # Block = BlankLine* (BlockQuote | Verbatim | HorizontalRule | Heading | BulletList | Para | Plain)
  def _Block

    _save = self.pos
    while true # sequence
      while true
        _tmp = apply(:_BlankLine)
        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end

      _save2 = self.pos
      while true # choice
        _tmp = apply(:_BlockQuote)
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Verbatim)
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_HorizontalRule)
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Heading)
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_BulletList)
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Para)
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Plain)
        break if _tmp
        self.pos = _save2
        break
      end # end choice

      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Block unless _tmp
    return _tmp
  end

  # Para = NonindentSpace Inlines:a BlankLine+ {para(self, position, a)}
  def _Para

    _save = self.pos
    while true # sequence
      _tmp = apply(:_NonindentSpace)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Inlines)
      a = @result
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_BlankLine)
      if _tmp
        while true
          _tmp = apply(:_BlankLine)
          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; para(self, position, a); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Para unless _tmp
    return _tmp
  end

  # Plain = Inlines:a {plain(self, position, a)}
  def _Plain

    _save = self.pos
    while true # sequence
      _tmp = apply(:_Inlines)
      a = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; plain(self, position, a); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Plain unless _tmp
    return _tmp
  end

  # AtxInline = !Newline !(Sp "#"* Sp Newline) Inline:c { c }
  def _AtxInline

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_Newline)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos

      _save3 = self.pos
      while true # sequence
        _tmp = apply(:_Sp)
        unless _tmp
          self.pos = _save3
          break
        end
        while true
          _tmp = match_string("#")
          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:_Sp)
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:_Newline)
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      _tmp = _tmp ? nil : true
      self.pos = _save2
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Inline)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_AtxInline unless _tmp
    return _tmp
  end

  # AtxStart = < /######|#####|####|###|##|#/ > { text.length }
  def _AtxStart

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:######|#####|####|###|##|#)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text.length ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_AtxStart unless _tmp
    return _tmp
  end

  # AtxHeading = AtxStart:level Sp AtxInline+:c (Sp "#"* Sp)? Newline {headline(self, position, level, c)}
  def _AtxHeading

    _save = self.pos
    while true # sequence
      _tmp = apply(:_AtxStart)
      level = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Sp)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_AtxInline)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_AtxInline)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos

      _save3 = self.pos
      while true # sequence
        _tmp = apply(:_Sp)
        unless _tmp
          self.pos = _save3
          break
        end
        while true
          _tmp = match_string("#")
          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:_Sp)
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      unless _tmp
        _tmp = true
        self.pos = _save2
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; headline(self, position, level, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_AtxHeading unless _tmp
    return _tmp
  end

  # Heading = AtxHeading
  def _Heading
    _tmp = apply(:_AtxHeading)
    set_failed_rule :_Heading unless _tmp
    return _tmp
  end

  # BlockQuote = BlockQuoteRaw:c {block_quote(self, position, c)}
  def _BlockQuote

    _save = self.pos
    while true # sequence
      _tmp = apply(:_BlockQuoteRaw)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; block_quote(self, position, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BlockQuote unless _tmp
    return _tmp
  end

  # BlockQuoteRaw = (">" " "? Line:c { c })+:cc { cc }
  def _BlockQuoteRaw

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []

      _save2 = self.pos
      while true # sequence
        _tmp = match_string(">")
        unless _tmp
          self.pos = _save2
          break
        end
        _save3 = self.pos
        _tmp = match_string(" ")
        unless _tmp
          _tmp = true
          self.pos = _save3
        end
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_Line)
        c = @result
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  c ; end
        _tmp = true
        unless _tmp
          self.pos = _save2
        end
        break
      end # end sequence

      if _tmp
        _ary << @result
        while true

          _save4 = self.pos
          while true # sequence
            _tmp = match_string(">")
            unless _tmp
              self.pos = _save4
              break
            end
            _save5 = self.pos
            _tmp = match_string(" ")
            unless _tmp
              _tmp = true
              self.pos = _save5
            end
            unless _tmp
              self.pos = _save4
              break
            end
            _tmp = apply(:_Line)
            c = @result
            unless _tmp
              self.pos = _save4
              break
            end
            @result = begin;  c ; end
            _tmp = true
            unless _tmp
              self.pos = _save4
            end
            break
          end # end sequence

          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      cc = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  cc ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BlockQuoteRaw unless _tmp
    return _tmp
  end

  # NonblankIndentedLine = !BlankLine IndentedLine:c { c }
  def _NonblankIndentedLine

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_BlankLine)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_IndentedLine)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_NonblankIndentedLine unless _tmp
    return _tmp
  end

  # VerbatimChunk = (BlankLine { text(self,position,"\n") })*:c1 (NonblankIndentedLine:c { [c, text(self,position,"\n")] })+:c2 { c1 + c2.flatten }
  def _VerbatimChunk

    _save = self.pos
    while true # sequence
      _ary = []
      while true

        _save2 = self.pos
        while true # sequence
          _tmp = apply(:_BlankLine)
          unless _tmp
            self.pos = _save2
            break
          end
          @result = begin;  text(self,position,"\n") ; end
          _tmp = true
          unless _tmp
            self.pos = _save2
          end
          break
        end # end sequence

        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      c1 = @result
      unless _tmp
        self.pos = _save
        break
      end
      _save3 = self.pos
      _ary = []

      _save4 = self.pos
      while true # sequence
        _tmp = apply(:_NonblankIndentedLine)
        c = @result
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin;  [c, text(self,position,"\n")] ; end
        _tmp = true
        unless _tmp
          self.pos = _save4
        end
        break
      end # end sequence

      if _tmp
        _ary << @result
        while true

          _save5 = self.pos
          while true # sequence
            _tmp = apply(:_NonblankIndentedLine)
            c = @result
            unless _tmp
              self.pos = _save5
              break
            end
            @result = begin;  [c, text(self,position,"\n")] ; end
            _tmp = true
            unless _tmp
              self.pos = _save5
            end
            break
          end # end sequence

          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save3
      end
      c2 = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c1 + c2.flatten ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_VerbatimChunk unless _tmp
    return _tmp
  end

  # Verbatim = VerbatimChunk+:cc {verbatim(self, position, cc.flatten)}
  def _Verbatim

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_VerbatimChunk)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_VerbatimChunk)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      cc = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; verbatim(self, position, cc.flatten); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Verbatim unless _tmp
    return _tmp
  end

  # HorizontalRule = NonindentSpace ("*" Sp "*" Sp "*" (Sp "*")* | "-" Sp "-" Sp "-" (Sp "-")* | "_" Sp "_" Sp "_" (Sp "_")*) Sp Newline BlankLine+ {horizontal_rule(self, position)}
  def _HorizontalRule

    _save = self.pos
    while true # sequence
      _tmp = apply(:_NonindentSpace)
      unless _tmp
        self.pos = _save
        break
      end

      _save1 = self.pos
      while true # choice

        _save2 = self.pos
        while true # sequence
          _tmp = match_string("*")
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = apply(:_Sp)
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = match_string("*")
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = apply(:_Sp)
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = match_string("*")
          unless _tmp
            self.pos = _save2
            break
          end
          while true

            _save4 = self.pos
            while true # sequence
              _tmp = apply(:_Sp)
              unless _tmp
                self.pos = _save4
                break
              end
              _tmp = match_string("*")
              unless _tmp
                self.pos = _save4
              end
              break
            end # end sequence

            break unless _tmp
          end
          _tmp = true
          unless _tmp
            self.pos = _save2
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save1

        _save5 = self.pos
        while true # sequence
          _tmp = match_string("-")
          unless _tmp
            self.pos = _save5
            break
          end
          _tmp = apply(:_Sp)
          unless _tmp
            self.pos = _save5
            break
          end
          _tmp = match_string("-")
          unless _tmp
            self.pos = _save5
            break
          end
          _tmp = apply(:_Sp)
          unless _tmp
            self.pos = _save5
            break
          end
          _tmp = match_string("-")
          unless _tmp
            self.pos = _save5
            break
          end
          while true

            _save7 = self.pos
            while true # sequence
              _tmp = apply(:_Sp)
              unless _tmp
                self.pos = _save7
                break
              end
              _tmp = match_string("-")
              unless _tmp
                self.pos = _save7
              end
              break
            end # end sequence

            break unless _tmp
          end
          _tmp = true
          unless _tmp
            self.pos = _save5
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save1

        _save8 = self.pos
        while true # sequence
          _tmp = match_string("_")
          unless _tmp
            self.pos = _save8
            break
          end
          _tmp = apply(:_Sp)
          unless _tmp
            self.pos = _save8
            break
          end
          _tmp = match_string("_")
          unless _tmp
            self.pos = _save8
            break
          end
          _tmp = apply(:_Sp)
          unless _tmp
            self.pos = _save8
            break
          end
          _tmp = match_string("_")
          unless _tmp
            self.pos = _save8
            break
          end
          while true

            _save10 = self.pos
            while true # sequence
              _tmp = apply(:_Sp)
              unless _tmp
                self.pos = _save10
                break
              end
              _tmp = match_string("_")
              unless _tmp
                self.pos = _save10
              end
              break
            end # end sequence

            break unless _tmp
          end
          _tmp = true
          unless _tmp
            self.pos = _save8
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save1
        break
      end # end choice

      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Sp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
        break
      end
      _save11 = self.pos
      _tmp = apply(:_BlankLine)
      if _tmp
        while true
          _tmp = apply(:_BlankLine)
          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save11
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; horizontal_rule(self, position); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_HorizontalRule unless _tmp
    return _tmp
  end

  # Bullet = !HorizontalRule NonindentSpace ("+" | "*" | "-") Spacechar+
  def _Bullet

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_HorizontalRule)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_NonindentSpace)
      unless _tmp
        self.pos = _save
        break
      end

      _save2 = self.pos
      while true # choice
        _tmp = match_string("+")
        break if _tmp
        self.pos = _save2
        _tmp = match_string("*")
        break if _tmp
        self.pos = _save2
        _tmp = match_string("-")
        break if _tmp
        self.pos = _save2
        break
      end # end choice

      unless _tmp
        self.pos = _save
        break
      end
      _save3 = self.pos
      _tmp = apply(:_Spacechar)
      if _tmp
        while true
          _tmp = apply(:_Spacechar)
          break unless _tmp
        end
        _tmp = true
      else
        self.pos = _save3
      end
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Bullet unless _tmp
    return _tmp
  end

  # BulletList = &Bullet ListTight:c {bullet_list(self, position, c)}
  def _BulletList

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_Bullet)
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_ListTight)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; bullet_list(self, position, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BulletList unless _tmp
    return _tmp
  end

  # ListTight = ListItemTight+:cc BlankLine* !Bullet { cc }
  def _ListTight

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_ListItemTight)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_ListItemTight)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      cc = @result
      unless _tmp
        self.pos = _save
        break
      end
      while true
        _tmp = apply(:_BlankLine)
        break unless _tmp
      end
      _tmp = true
      unless _tmp
        self.pos = _save
        break
      end
      _save3 = self.pos
      _tmp = apply(:_Bullet)
      _tmp = _tmp ? nil : true
      self.pos = _save3
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  cc ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ListTight unless _tmp
    return _tmp
  end

  # ListItemTight = Bullet ListBlock:c {bullet_list_item(self, position, c)}
  def _ListItemTight

    _save = self.pos
    while true # sequence
      _tmp = apply(:_Bullet)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_ListBlock)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; bullet_list_item(self, position, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ListItemTight unless _tmp
    return _tmp
  end

  # ListBlock = !BlankLine Line:c ListBlockLine*:cc { cc.unshift(c) }
  def _ListBlock

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_BlankLine)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Line)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      _ary = []
      while true
        _tmp = apply(:_ListBlockLine)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      cc = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  cc.unshift(c) ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ListBlock unless _tmp
    return _tmp
  end

  # ListBlockLine = !BlankLine !(Indent? Bullet) !HorizontalRule OptionallyIndentedLine
  def _ListBlockLine

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_BlankLine)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos

      _save3 = self.pos
      while true # sequence
        _save4 = self.pos
        _tmp = apply(:_Indent)
        unless _tmp
          _tmp = true
          self.pos = _save4
        end
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:_Bullet)
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      _tmp = _tmp ? nil : true
      self.pos = _save2
      unless _tmp
        self.pos = _save
        break
      end
      _save5 = self.pos
      _tmp = apply(:_HorizontalRule)
      _tmp = _tmp ? nil : true
      self.pos = _save5
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_OptionallyIndentedLine)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_ListBlockLine unless _tmp
    return _tmp
  end

  # Inlines = (!Endline Inline:c { c } | Endline:c &Inline { c })+:cc Endline? { cc }
  def _Inlines

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []

      _save2 = self.pos
      while true # choice

        _save3 = self.pos
        while true # sequence
          _save4 = self.pos
          _tmp = apply(:_Endline)
          _tmp = _tmp ? nil : true
          self.pos = _save4
          unless _tmp
            self.pos = _save3
            break
          end
          _tmp = apply(:_Inline)
          c = @result
          unless _tmp
            self.pos = _save3
            break
          end
          @result = begin;  c ; end
          _tmp = true
          unless _tmp
            self.pos = _save3
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2

        _save5 = self.pos
        while true # sequence
          _tmp = apply(:_Endline)
          c = @result
          unless _tmp
            self.pos = _save5
            break
          end
          _save6 = self.pos
          _tmp = apply(:_Inline)
          self.pos = _save6
          unless _tmp
            self.pos = _save5
            break
          end
          @result = begin;  c ; end
          _tmp = true
          unless _tmp
            self.pos = _save5
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2
        break
      end # end choice

      if _tmp
        _ary << @result
        while true

          _save7 = self.pos
          while true # choice

            _save8 = self.pos
            while true # sequence
              _save9 = self.pos
              _tmp = apply(:_Endline)
              _tmp = _tmp ? nil : true
              self.pos = _save9
              unless _tmp
                self.pos = _save8
                break
              end
              _tmp = apply(:_Inline)
              c = @result
              unless _tmp
                self.pos = _save8
                break
              end
              @result = begin;  c ; end
              _tmp = true
              unless _tmp
                self.pos = _save8
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save7

            _save10 = self.pos
            while true # sequence
              _tmp = apply(:_Endline)
              c = @result
              unless _tmp
                self.pos = _save10
                break
              end
              _save11 = self.pos
              _tmp = apply(:_Inline)
              self.pos = _save11
              unless _tmp
                self.pos = _save10
                break
              end
              @result = begin;  c ; end
              _tmp = true
              unless _tmp
                self.pos = _save10
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save7
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
      cc = @result
      unless _tmp
        self.pos = _save
        break
      end
      _save12 = self.pos
      _tmp = apply(:_Endline)
      unless _tmp
        _tmp = true
        self.pos = _save12
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  cc ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Inlines unless _tmp
    return _tmp
  end

  # Inline = (Str | Endline | Space | Strong | Emph | Code | Symbol)
  def _Inline

    _save = self.pos
    while true # choice
      _tmp = apply(:_Str)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Endline)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Space)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Strong)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Emph)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Code)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Symbol)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Inline unless _tmp
    return _tmp
  end

  # Space = Spacechar+:c {text(self, position, c.join(""))}
  def _Space

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_Spacechar)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_Spacechar)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text(self, position, c.join("")); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Space unless _tmp
    return _tmp
  end

  # Str = NormalChar+:c1 StrChunk*:c2 {text(self, position, (c1+c2).join(""))}
  def _Str

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_NormalChar)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_NormalChar)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      c1 = @result
      unless _tmp
        self.pos = _save
        break
      end
      _ary = []
      while true
        _tmp = apply(:_StrChunk)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      c2 = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text(self, position, (c1+c2).join("")); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Str unless _tmp
    return _tmp
  end

  # StrChunk = (NormalChar:c { [c] } | "_"+:c1 NormalChar:c2 { c1.push(c2) })+:cc { cc.flatten }
  def _StrChunk

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []

      _save2 = self.pos
      while true # choice

        _save3 = self.pos
        while true # sequence
          _tmp = apply(:_NormalChar)
          c = @result
          unless _tmp
            self.pos = _save3
            break
          end
          @result = begin;  [c] ; end
          _tmp = true
          unless _tmp
            self.pos = _save3
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2

        _save4 = self.pos
        while true # sequence
          _save5 = self.pos
          _ary = []
          _tmp = match_string("_")
          if _tmp
            _ary << @result
            while true
              _tmp = match_string("_")
              _ary << @result if _tmp
              break unless _tmp
            end
            _tmp = true
            @result = _ary
          else
            self.pos = _save5
          end
          c1 = @result
          unless _tmp
            self.pos = _save4
            break
          end
          _tmp = apply(:_NormalChar)
          c2 = @result
          unless _tmp
            self.pos = _save4
            break
          end
          @result = begin;  c1.push(c2) ; end
          _tmp = true
          unless _tmp
            self.pos = _save4
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save2
        break
      end # end choice

      if _tmp
        _ary << @result
        while true

          _save6 = self.pos
          while true # choice

            _save7 = self.pos
            while true # sequence
              _tmp = apply(:_NormalChar)
              c = @result
              unless _tmp
                self.pos = _save7
                break
              end
              @result = begin;  [c] ; end
              _tmp = true
              unless _tmp
                self.pos = _save7
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save6

            _save8 = self.pos
            while true # sequence
              _save9 = self.pos
              _ary = []
              _tmp = match_string("_")
              if _tmp
                _ary << @result
                while true
                  _tmp = match_string("_")
                  _ary << @result if _tmp
                  break unless _tmp
                end
                _tmp = true
                @result = _ary
              else
                self.pos = _save9
              end
              c1 = @result
              unless _tmp
                self.pos = _save8
                break
              end
              _tmp = apply(:_NormalChar)
              c2 = @result
              unless _tmp
                self.pos = _save8
                break
              end
              @result = begin;  c1.push(c2) ; end
              _tmp = true
              unless _tmp
                self.pos = _save8
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save6
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
      cc = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  cc.flatten ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_StrChunk unless _tmp
    return _tmp
  end

  # Endline = (LineBreak | TerminalEndline | NormalEndline)
  def _Endline

    _save = self.pos
    while true # choice
      _tmp = apply(:_LineBreak)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_TerminalEndline)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_NormalEndline)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Endline unless _tmp
    return _tmp
  end

  # NormalEndline = Sp Newline !BlankLine !">" !AtxStart !(Line ("="+ | "-"+) Newline) {text(self, position, "\n")}
  def _NormalEndline

    _save = self.pos
    while true # sequence
      _tmp = apply(:_Sp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_BlankLine)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _tmp = match_string(">")
      _tmp = _tmp ? nil : true
      self.pos = _save2
      unless _tmp
        self.pos = _save
        break
      end
      _save3 = self.pos
      _tmp = apply(:_AtxStart)
      _tmp = _tmp ? nil : true
      self.pos = _save3
      unless _tmp
        self.pos = _save
        break
      end
      _save4 = self.pos

      _save5 = self.pos
      while true # sequence
        _tmp = apply(:_Line)
        unless _tmp
          self.pos = _save5
          break
        end

        _save6 = self.pos
        while true # choice
          _save7 = self.pos
          _tmp = match_string("=")
          if _tmp
            while true
              _tmp = match_string("=")
              break unless _tmp
            end
            _tmp = true
          else
            self.pos = _save7
          end
          break if _tmp
          self.pos = _save6
          _save8 = self.pos
          _tmp = match_string("-")
          if _tmp
            while true
              _tmp = match_string("-")
              break unless _tmp
            end
            _tmp = true
          else
            self.pos = _save8
          end
          break if _tmp
          self.pos = _save6
          break
        end # end choice

        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = apply(:_Newline)
        unless _tmp
          self.pos = _save5
        end
        break
      end # end sequence

      _tmp = _tmp ? nil : true
      self.pos = _save4
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text(self, position, "\n"); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_NormalEndline unless _tmp
    return _tmp
  end

  # TerminalEndline = Sp Newline Eof {text(self, position, "\n")}
  def _TerminalEndline

    _save = self.pos
    while true # sequence
      _tmp = apply(:_Sp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Eof)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text(self, position, "\n"); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_TerminalEndline unless _tmp
    return _tmp
  end

  # LineBreak = "  " NormalEndline {linebreak(self, position)}
  def _LineBreak

    _save = self.pos
    while true # sequence
      _tmp = match_string("  ")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_NormalEndline)
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; linebreak(self, position); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_LineBreak unless _tmp
    return _tmp
  end

  # Symbol = SpecialChar:c {text(self, position, c)}
  def _Symbol

    _save = self.pos
    while true # sequence
      _tmp = apply(:_SpecialChar)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text(self, position, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Symbol unless _tmp
    return _tmp
  end

  # Emph = (EmphStar | EmphUl)
  def _Emph

    _save = self.pos
    while true # choice
      _tmp = apply(:_EmphStar)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_EmphUl)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Emph unless _tmp
    return _tmp
  end

  # Whitespace = (Spacechar | Newline)
  def _Whitespace

    _save = self.pos
    while true # choice
      _tmp = apply(:_Spacechar)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_Newline)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Whitespace unless _tmp
    return _tmp
  end

  # EmphStar = "*" !Whitespace (!"*" Inline:b { b } | StrongStar:b { b })+:c "*" {inline_element(self, position, :em, c)}
  def _EmphStar

    _save = self.pos
    while true # sequence
      _tmp = match_string("*")
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_Whitespace)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _ary = []

      _save3 = self.pos
      while true # choice

        _save4 = self.pos
        while true # sequence
          _save5 = self.pos
          _tmp = match_string("*")
          _tmp = _tmp ? nil : true
          self.pos = _save5
          unless _tmp
            self.pos = _save4
            break
          end
          _tmp = apply(:_Inline)
          b = @result
          unless _tmp
            self.pos = _save4
            break
          end
          @result = begin;  b ; end
          _tmp = true
          unless _tmp
            self.pos = _save4
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save3

        _save6 = self.pos
        while true # sequence
          _tmp = apply(:_StrongStar)
          b = @result
          unless _tmp
            self.pos = _save6
            break
          end
          @result = begin;  b ; end
          _tmp = true
          unless _tmp
            self.pos = _save6
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save3
        break
      end # end choice

      if _tmp
        _ary << @result
        while true

          _save7 = self.pos
          while true # choice

            _save8 = self.pos
            while true # sequence
              _save9 = self.pos
              _tmp = match_string("*")
              _tmp = _tmp ? nil : true
              self.pos = _save9
              unless _tmp
                self.pos = _save8
                break
              end
              _tmp = apply(:_Inline)
              b = @result
              unless _tmp
                self.pos = _save8
                break
              end
              @result = begin;  b ; end
              _tmp = true
              unless _tmp
                self.pos = _save8
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save7

            _save10 = self.pos
            while true # sequence
              _tmp = apply(:_StrongStar)
              b = @result
              unless _tmp
                self.pos = _save10
                break
              end
              @result = begin;  b ; end
              _tmp = true
              unless _tmp
                self.pos = _save10
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save7
            break
          end # end choice

          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save2
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("*")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; inline_element(self, position, :em, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_EmphStar unless _tmp
    return _tmp
  end

  # EmphUl = "_" !Whitespace (!"_" Inline:b { b } | StrongUl:b { b })+:c "_" {inline_element(self, position, :em, c)}
  def _EmphUl

    _save = self.pos
    while true # sequence
      _tmp = match_string("_")
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_Whitespace)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _ary = []

      _save3 = self.pos
      while true # choice

        _save4 = self.pos
        while true # sequence
          _save5 = self.pos
          _tmp = match_string("_")
          _tmp = _tmp ? nil : true
          self.pos = _save5
          unless _tmp
            self.pos = _save4
            break
          end
          _tmp = apply(:_Inline)
          b = @result
          unless _tmp
            self.pos = _save4
            break
          end
          @result = begin;  b ; end
          _tmp = true
          unless _tmp
            self.pos = _save4
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save3

        _save6 = self.pos
        while true # sequence
          _tmp = apply(:_StrongUl)
          b = @result
          unless _tmp
            self.pos = _save6
            break
          end
          @result = begin;  b ; end
          _tmp = true
          unless _tmp
            self.pos = _save6
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save3
        break
      end # end choice

      if _tmp
        _ary << @result
        while true

          _save7 = self.pos
          while true # choice

            _save8 = self.pos
            while true # sequence
              _save9 = self.pos
              _tmp = match_string("_")
              _tmp = _tmp ? nil : true
              self.pos = _save9
              unless _tmp
                self.pos = _save8
                break
              end
              _tmp = apply(:_Inline)
              b = @result
              unless _tmp
                self.pos = _save8
                break
              end
              @result = begin;  b ; end
              _tmp = true
              unless _tmp
                self.pos = _save8
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save7

            _save10 = self.pos
            while true # sequence
              _tmp = apply(:_StrongUl)
              b = @result
              unless _tmp
                self.pos = _save10
                break
              end
              @result = begin;  b ; end
              _tmp = true
              unless _tmp
                self.pos = _save10
              end
              break
            end # end sequence

            break if _tmp
            self.pos = _save7
            break
          end # end choice

          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save2
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("_")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; inline_element(self, position, :em, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_EmphUl unless _tmp
    return _tmp
  end

  # Strong = (StrongStar | StrongUl)
  def _Strong

    _save = self.pos
    while true # choice
      _tmp = apply(:_StrongStar)
      break if _tmp
      self.pos = _save
      _tmp = apply(:_StrongUl)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Strong unless _tmp
    return _tmp
  end

  # StrongStar = "**" !Whitespace (!"**" Inline:b { b })+:c "**" {inline_element(self, position, :strong, c)}
  def _StrongStar

    _save = self.pos
    while true # sequence
      _tmp = match_string("**")
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_Whitespace)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _ary = []

      _save3 = self.pos
      while true # sequence
        _save4 = self.pos
        _tmp = match_string("**")
        _tmp = _tmp ? nil : true
        self.pos = _save4
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:_Inline)
        b = @result
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin;  b ; end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      if _tmp
        _ary << @result
        while true

          _save5 = self.pos
          while true # sequence
            _save6 = self.pos
            _tmp = match_string("**")
            _tmp = _tmp ? nil : true
            self.pos = _save6
            unless _tmp
              self.pos = _save5
              break
            end
            _tmp = apply(:_Inline)
            b = @result
            unless _tmp
              self.pos = _save5
              break
            end
            @result = begin;  b ; end
            _tmp = true
            unless _tmp
              self.pos = _save5
            end
            break
          end # end sequence

          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save2
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("**")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; inline_element(self, position, :strong, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_StrongStar unless _tmp
    return _tmp
  end

  # StrongUl = "__" !Whitespace (!"__" Inline:b { b })+:c "__" {inline_element(self, position, :strong, c)}
  def _StrongUl

    _save = self.pos
    while true # sequence
      _tmp = match_string("__")
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = apply(:_Whitespace)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _ary = []

      _save3 = self.pos
      while true # sequence
        _save4 = self.pos
        _tmp = match_string("__")
        _tmp = _tmp ? nil : true
        self.pos = _save4
        unless _tmp
          self.pos = _save3
          break
        end
        _tmp = apply(:_Inline)
        b = @result
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin;  b ; end
        _tmp = true
        unless _tmp
          self.pos = _save3
        end
        break
      end # end sequence

      if _tmp
        _ary << @result
        while true

          _save5 = self.pos
          while true # sequence
            _save6 = self.pos
            _tmp = match_string("__")
            _tmp = _tmp ? nil : true
            self.pos = _save6
            unless _tmp
              self.pos = _save5
              break
            end
            _tmp = apply(:_Inline)
            b = @result
            unless _tmp
              self.pos = _save5
              break
            end
            @result = begin;  b ; end
            _tmp = true
            unless _tmp
              self.pos = _save5
            end
            break
          end # end sequence

          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save2
      end
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("__")
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; inline_element(self, position, :strong, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_StrongUl unless _tmp
    return _tmp
  end

  # Ticks1 = < /`/ > !"`" { text }
  def _Ticks1

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:`)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = match_string("`")
      _tmp = _tmp ? nil : true
      self.pos = _save1
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

    set_failed_rule :_Ticks1 unless _tmp
    return _tmp
  end

  # Ticks2 = < /``/ > !"`" { text }
  def _Ticks2

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:``)/)
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos
      _tmp = match_string("`")
      _tmp = _tmp ? nil : true
      self.pos = _save1
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

    set_failed_rule :_Ticks2 unless _tmp
    return _tmp
  end

  # Code = (Ticks1 Sp (!"`" Nonspacechar)+:c Sp Ticks1 {text(self, position, c.join(""))} | Ticks2 Sp (!"``" Nonspacechar)+:c Sp Ticks2 {text(self, position, c.join(""))}):cc {inline_element(self, position, :code, [cc])}
  def _Code

    _save = self.pos
    while true # sequence

      _save1 = self.pos
      while true # choice

        _save2 = self.pos
        while true # sequence
          _tmp = apply(:_Ticks1)
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = apply(:_Sp)
          unless _tmp
            self.pos = _save2
            break
          end
          _save3 = self.pos
          _ary = []

          _save4 = self.pos
          while true # sequence
            _save5 = self.pos
            _tmp = match_string("`")
            _tmp = _tmp ? nil : true
            self.pos = _save5
            unless _tmp
              self.pos = _save4
              break
            end
            _tmp = apply(:_Nonspacechar)
            unless _tmp
              self.pos = _save4
            end
            break
          end # end sequence

          if _tmp
            _ary << @result
            while true

              _save6 = self.pos
              while true # sequence
                _save7 = self.pos
                _tmp = match_string("`")
                _tmp = _tmp ? nil : true
                self.pos = _save7
                unless _tmp
                  self.pos = _save6
                  break
                end
                _tmp = apply(:_Nonspacechar)
                unless _tmp
                  self.pos = _save6
                end
                break
              end # end sequence

              _ary << @result if _tmp
              break unless _tmp
            end
            _tmp = true
            @result = _ary
          else
            self.pos = _save3
          end
          c = @result
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = apply(:_Sp)
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = apply(:_Ticks1)
          unless _tmp
            self.pos = _save2
            break
          end
          @result = begin; text(self, position, c.join("")); end
          _tmp = true
          unless _tmp
            self.pos = _save2
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save1

        _save8 = self.pos
        while true # sequence
          _tmp = apply(:_Ticks2)
          unless _tmp
            self.pos = _save8
            break
          end
          _tmp = apply(:_Sp)
          unless _tmp
            self.pos = _save8
            break
          end
          _save9 = self.pos
          _ary = []

          _save10 = self.pos
          while true # sequence
            _save11 = self.pos
            _tmp = match_string("``")
            _tmp = _tmp ? nil : true
            self.pos = _save11
            unless _tmp
              self.pos = _save10
              break
            end
            _tmp = apply(:_Nonspacechar)
            unless _tmp
              self.pos = _save10
            end
            break
          end # end sequence

          if _tmp
            _ary << @result
            while true

              _save12 = self.pos
              while true # sequence
                _save13 = self.pos
                _tmp = match_string("``")
                _tmp = _tmp ? nil : true
                self.pos = _save13
                unless _tmp
                  self.pos = _save12
                  break
                end
                _tmp = apply(:_Nonspacechar)
                unless _tmp
                  self.pos = _save12
                end
                break
              end # end sequence

              _ary << @result if _tmp
              break unless _tmp
            end
            _tmp = true
            @result = _ary
          else
            self.pos = _save9
          end
          c = @result
          unless _tmp
            self.pos = _save8
            break
          end
          _tmp = apply(:_Sp)
          unless _tmp
            self.pos = _save8
            break
          end
          _tmp = apply(:_Ticks2)
          unless _tmp
            self.pos = _save8
            break
          end
          @result = begin; text(self, position, c.join("")); end
          _tmp = true
          unless _tmp
            self.pos = _save8
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save1
        break
      end # end choice

      cc = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; inline_element(self, position, :code, [cc]); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Code unless _tmp
    return _tmp
  end

  # BlankLine = Sp Newline
  def _BlankLine

    _save = self.pos
    while true # sequence
      _tmp = apply(:_Sp)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Newline)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_BlankLine unless _tmp
    return _tmp
  end

  # Quoted = ("\"" (!"\"" .)* "\"" | "'" (!"'" .)* "'")
  def _Quoted

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("\"")
        unless _tmp
          self.pos = _save1
          break
        end
        while true

          _save3 = self.pos
          while true # sequence
            _save4 = self.pos
            _tmp = match_string("\"")
            _tmp = _tmp ? nil : true
            self.pos = _save4
            unless _tmp
              self.pos = _save3
              break
            end
            _tmp = get_byte
            unless _tmp
              self.pos = _save3
            end
            break
          end # end sequence

          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save1
          break
        end
        _tmp = match_string("\"")
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save

      _save5 = self.pos
      while true # sequence
        _tmp = match_string("'")
        unless _tmp
          self.pos = _save5
          break
        end
        while true

          _save7 = self.pos
          while true # sequence
            _save8 = self.pos
            _tmp = match_string("'")
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

          break unless _tmp
        end
        _tmp = true
        unless _tmp
          self.pos = _save5
          break
        end
        _tmp = match_string("'")
        unless _tmp
          self.pos = _save5
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Quoted unless _tmp
    return _tmp
  end

  # Eof = !.
  def _Eof
    _save = self.pos
    _tmp = get_byte
    _tmp = _tmp ? nil : true
    self.pos = _save
    set_failed_rule :_Eof unless _tmp
    return _tmp
  end

  # Spacechar = < / |\t/ > { text }
  def _Spacechar

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix: |\t)/)
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

    set_failed_rule :_Spacechar unless _tmp
    return _tmp
  end

  # Nonspacechar = !Spacechar !Newline < . > { text }
  def _Nonspacechar

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_Spacechar)
      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _save2 = self.pos
      _tmp = apply(:_Newline)
      _tmp = _tmp ? nil : true
      self.pos = _save2
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _tmp = get_byte
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

    set_failed_rule :_Nonspacechar unless _tmp
    return _tmp
  end

  # Newline = ("\n" | "\r" "\n"?)
  def _Newline

    _save = self.pos
    while true # choice
      _tmp = match_string("\n")
      break if _tmp
      self.pos = _save

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("\r")
        unless _tmp
          self.pos = _save1
          break
        end
        _save2 = self.pos
        _tmp = match_string("\n")
        unless _tmp
          _tmp = true
          self.pos = _save2
        end
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_Newline unless _tmp
    return _tmp
  end

  # Sp = Spacechar*
  def _Sp
    while true
      _tmp = apply(:_Spacechar)
      break unless _tmp
    end
    _tmp = true
    set_failed_rule :_Sp unless _tmp
    return _tmp
  end

  # Spnl = Sp (Newline Sp)?
  def _Spnl

    _save = self.pos
    while true # sequence
      _tmp = apply(:_Sp)
      unless _tmp
        self.pos = _save
        break
      end
      _save1 = self.pos

      _save2 = self.pos
      while true # sequence
        _tmp = apply(:_Newline)
        unless _tmp
          self.pos = _save2
          break
        end
        _tmp = apply(:_Sp)
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

    set_failed_rule :_Spnl unless _tmp
    return _tmp
  end

  # SpecialChar = < /[~*_`&\[\]()<!#\\'"]/ > { text }
  def _SpecialChar

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[~*_`&\[\]()<!#\\'"])/)
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

    set_failed_rule :_SpecialChar unless _tmp
    return _tmp
  end

  # NormalChar = !(SpecialChar | Spacechar | Newline) < . > { text }
  def _NormalChar

    _save = self.pos
    while true # sequence
      _save1 = self.pos

      _save2 = self.pos
      while true # choice
        _tmp = apply(:_SpecialChar)
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Spacechar)
        break if _tmp
        self.pos = _save2
        _tmp = apply(:_Newline)
        break if _tmp
        self.pos = _save2
        break
      end # end choice

      _tmp = _tmp ? nil : true
      self.pos = _save1
      unless _tmp
        self.pos = _save
        break
      end
      _text_start = self.pos
      _tmp = get_byte
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

    set_failed_rule :_NormalChar unless _tmp
    return _tmp
  end

  # AlphanumericAscii = < /[A-Za-z0-9]/ > { text }
  def _AlphanumericAscii

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[A-Za-z0-9])/)
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

    set_failed_rule :_AlphanumericAscii unless _tmp
    return _tmp
  end

  # Digit = < /[0-9]/ > { text }
  def _Digit

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:[0-9])/)
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

    set_failed_rule :_Digit unless _tmp
    return _tmp
  end

  # NonindentSpace = < /   |  | |/ > { text }
  def _NonindentSpace

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:   |  | |)/)
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

    set_failed_rule :_NonindentSpace unless _tmp
    return _tmp
  end

  # Indent = < /\t|    / > { text }
  def _Indent

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = scan(/\A(?-mix:\t|    )/)
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

    set_failed_rule :_Indent unless _tmp
    return _tmp
  end

  # IndentedLine = Indent Line:c { c }
  def _IndentedLine

    _save = self.pos
    while true # sequence
      _tmp = apply(:_Indent)
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Line)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_IndentedLine unless _tmp
    return _tmp
  end

  # OptionallyIndentedLine = Indent? Line
  def _OptionallyIndentedLine

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_Indent)
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = apply(:_Line)
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_OptionallyIndentedLine unless _tmp
    return _tmp
  end

  # Line = RawLine:c { c }
  def _Line

    _save = self.pos
    while true # sequence
      _tmp = apply(:_RawLine)
      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  c ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_Line unless _tmp
    return _tmp
  end

  # RawLine = (< /[^\r\n]*/ > Newline { text } | < /.+/ > Eof { text }):c {text(self, position, c)}
  def _RawLine

    _save = self.pos
    while true # sequence

      _save1 = self.pos
      while true # choice

        _save2 = self.pos
        while true # sequence
          _text_start = self.pos
          _tmp = scan(/\A(?-mix:[^\r\n]*)/)
          if _tmp
            text = get_text(_text_start)
          end
          unless _tmp
            self.pos = _save2
            break
          end
          _tmp = apply(:_Newline)
          unless _tmp
            self.pos = _save2
            break
          end
          @result = begin;  text ; end
          _tmp = true
          unless _tmp
            self.pos = _save2
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save1

        _save3 = self.pos
        while true # sequence
          _text_start = self.pos
          _tmp = scan(/\A(?-mix:.+)/)
          if _tmp
            text = get_text(_text_start)
          end
          unless _tmp
            self.pos = _save3
            break
          end
          _tmp = apply(:_Eof)
          unless _tmp
            self.pos = _save3
            break
          end
          @result = begin;  text ; end
          _tmp = true
          unless _tmp
            self.pos = _save3
          end
          break
        end # end sequence

        break if _tmp
        self.pos = _save1
        break
      end # end choice

      c = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text(self, position, c); end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_RawLine unless _tmp
    return _tmp
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
