require 'kpeg/compiled_parser'

class KPeg::FormatParser < KPeg::CompiledParser


    require 'kpeg/grammar'

    def initialize(str, debug=false)
      setup_parser(str, debug)
      @g = KPeg::Grammar.new
    end

    attr_reader :g
    alias_method :grammar, :g



  # eol = "\n"
  def _eol
    _tmp = match_string("\n")
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
    _tmp = apply('eol', :_eol)
    self.pos = _save3
    _tmp = _tmp ? nil : true
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
    _tmp = apply('eol', :_eol)
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    return _tmp
  end

  # space = (" " | "\t" | eol)
  def _space

    _save4 = self.pos
    while true # choice
    _tmp = match_string(" ")
    break if _tmp
    self.pos = _save4
    _tmp = match_string("\t")
    break if _tmp
    self.pos = _save4
    _tmp = apply('eol', :_eol)
    break if _tmp
    self.pos = _save4
    break
    end # end choice

    return _tmp
  end

  # - = (space | comment)*
  def __hyphen_
    while true

    _save6 = self.pos
    while true # choice
    _tmp = apply('space', :_space)
    break if _tmp
    self.pos = _save6
    _tmp = apply('comment', :_comment)
    break if _tmp
    self.pos = _save6
    break
    end # end choice

    break unless _tmp
    end
    _tmp = true
    return _tmp
  end

  # var = < ("-" | /[a-zA-Z][\-_a-zA-Z0-9]*/) > { text }
  def _var

    _save7 = self.pos
    while true # sequence
    _text_start = self.pos

    _save8 = self.pos
    while true # choice
    _tmp = match_string("-")
    break if _tmp
    self.pos = _save8
    _tmp = scan(/\A(?-mix:[a-zA-Z][\-_a-zA-Z0-9]*)/)
    break if _tmp
    self.pos = _save8
    break
    end # end choice

    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save7
      break
    end
    @result = begin;  text ; end
    _tmp = true
    unless _tmp
      self.pos = _save7
    end
    break
    end # end sequence

    return _tmp
  end

  # dbl_escapes = ("\\\"" { '"' } | "\\n" { "\n" } | "\\t" { "\t" } | "\\\\" { "\\" })
  def _dbl_escapes

    _save9 = self.pos
    while true # choice

    _save10 = self.pos
    while true # sequence
    _tmp = match_string("\\\"")
    unless _tmp
      self.pos = _save10
      break
    end
    @result = begin;  '"' ; end
    _tmp = true
    unless _tmp
      self.pos = _save10
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save9

    _save11 = self.pos
    while true # sequence
    _tmp = match_string("\\n")
    unless _tmp
      self.pos = _save11
      break
    end
    @result = begin;  "\n" ; end
    _tmp = true
    unless _tmp
      self.pos = _save11
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save9

    _save12 = self.pos
    while true # sequence
    _tmp = match_string("\\t")
    unless _tmp
      self.pos = _save12
      break
    end
    @result = begin;  "\t" ; end
    _tmp = true
    unless _tmp
      self.pos = _save12
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save9

    _save13 = self.pos
    while true # sequence
    _tmp = match_string("\\\\")
    unless _tmp
      self.pos = _save13
      break
    end
    @result = begin;  "\\" ; end
    _tmp = true
    unless _tmp
      self.pos = _save13
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save9
    break
    end # end choice

    return _tmp
  end

  # dbl_seq = < /[^\\"]+/ > { text }
  def _dbl_seq

    _save14 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = scan(/\A(?-mix:[^\\"]+)/)
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save14
      break
    end
    @result = begin;  text ; end
    _tmp = true
    unless _tmp
      self.pos = _save14
    end
    break
    end # end sequence

    return _tmp
  end

  # dbl_not_quote = (dbl_escapes:s | dbl_seq:s)+:ary { ary }
  def _dbl_not_quote

    _save15 = self.pos
    while true # sequence
    _save16 = self.pos
    _ary = []

    _save17 = self.pos
    while true # choice
    _tmp = apply('dbl_escapes', :_dbl_escapes)
    s = @result
    break if _tmp
    self.pos = _save17
    _tmp = apply('dbl_seq', :_dbl_seq)
    s = @result
    break if _tmp
    self.pos = _save17
    break
    end # end choice

    if _tmp
      _ary << @result
      while true
    
    _save18 = self.pos
    while true # choice
    _tmp = apply('dbl_escapes', :_dbl_escapes)
    s = @result
    break if _tmp
    self.pos = _save18
    _tmp = apply('dbl_seq', :_dbl_seq)
    s = @result
    break if _tmp
    self.pos = _save18
    break
    end # end choice

        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
    else
      self.pos = _save16
    end
    ary = @result
    unless _tmp
      self.pos = _save15
      break
    end
    @result = begin;  ary ; end
    _tmp = true
    unless _tmp
      self.pos = _save15
    end
    break
    end # end sequence

    return _tmp
  end

  # dbl_string = "\"" dbl_not_quote:s "\"" { @g.str(s.join) }
  def _dbl_string

    _save19 = self.pos
    while true # sequence
    _tmp = match_string("\"")
    unless _tmp
      self.pos = _save19
      break
    end
    _tmp = apply('dbl_not_quote', :_dbl_not_quote)
    s = @result
    unless _tmp
      self.pos = _save19
      break
    end
    _tmp = match_string("\"")
    unless _tmp
      self.pos = _save19
      break
    end
    @result = begin;  @g.str(s.join) ; end
    _tmp = true
    unless _tmp
      self.pos = _save19
    end
    break
    end # end sequence

    return _tmp
  end

  # sgl_escape_quote = "\\'" { "'" }
  def _sgl_escape_quote

    _save20 = self.pos
    while true # sequence
    _tmp = match_string("\\'")
    unless _tmp
      self.pos = _save20
      break
    end
    @result = begin;  "'" ; end
    _tmp = true
    unless _tmp
      self.pos = _save20
    end
    break
    end # end sequence

    return _tmp
  end

  # sgl_seq = < /[^']/ > { text }
  def _sgl_seq

    _save21 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = scan(/\A(?-mix:[^'])/)
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save21
      break
    end
    @result = begin;  text ; end
    _tmp = true
    unless _tmp
      self.pos = _save21
    end
    break
    end # end sequence

    return _tmp
  end

  # sgl_not_quote = (sgl_escape_quote | sgl_seq)+:segs { segs.join }
  def _sgl_not_quote

    _save22 = self.pos
    while true # sequence
    _save23 = self.pos
    _ary = []

    _save24 = self.pos
    while true # choice
    _tmp = apply('sgl_escape_quote', :_sgl_escape_quote)
    break if _tmp
    self.pos = _save24
    _tmp = apply('sgl_seq', :_sgl_seq)
    break if _tmp
    self.pos = _save24
    break
    end # end choice

    if _tmp
      _ary << @result
      while true
    
    _save25 = self.pos
    while true # choice
    _tmp = apply('sgl_escape_quote', :_sgl_escape_quote)
    break if _tmp
    self.pos = _save25
    _tmp = apply('sgl_seq', :_sgl_seq)
    break if _tmp
    self.pos = _save25
    break
    end # end choice

        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
    else
      self.pos = _save23
    end
    segs = @result
    unless _tmp
      self.pos = _save22
      break
    end
    @result = begin;  segs.join ; end
    _tmp = true
    unless _tmp
      self.pos = _save22
    end
    break
    end # end sequence

    return _tmp
  end

  # sgl_string = "'" sgl_not_quote:s "'" { @g.str(s) }
  def _sgl_string

    _save26 = self.pos
    while true # sequence
    _tmp = match_string("'")
    unless _tmp
      self.pos = _save26
      break
    end
    _tmp = apply('sgl_not_quote', :_sgl_not_quote)
    s = @result
    unless _tmp
      self.pos = _save26
      break
    end
    _tmp = match_string("'")
    unless _tmp
      self.pos = _save26
      break
    end
    @result = begin;  @g.str(s) ; end
    _tmp = true
    unless _tmp
      self.pos = _save26
    end
    break
    end # end sequence

    return _tmp
  end

  # string = (dbl_string | sgl_string)
  def _string

    _save27 = self.pos
    while true # choice
    _tmp = apply('dbl_string', :_dbl_string)
    break if _tmp
    self.pos = _save27
    _tmp = apply('sgl_string', :_sgl_string)
    break if _tmp
    self.pos = _save27
    break
    end # end choice

    return _tmp
  end

  # not_slash = ("\\/" | /[^\/]/)+
  def _not_slash
    _save28 = self.pos

    _save29 = self.pos
    while true # choice
    _tmp = match_string("\\/")
    break if _tmp
    self.pos = _save29
    _tmp = scan(/\A(?-mix:[^\/])/)
    break if _tmp
    self.pos = _save29
    break
    end # end choice

    if _tmp
      while true
    
    _save30 = self.pos
    while true # choice
    _tmp = match_string("\\/")
    break if _tmp
    self.pos = _save30
    _tmp = scan(/\A(?-mix:[^\/])/)
    break if _tmp
    self.pos = _save30
    break
    end # end choice

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save28
    end
    return _tmp
  end

  # regexp = "/" < not_slash > "/" { @g.reg(Regexp.new(text)) }
  def _regexp

    _save31 = self.pos
    while true # sequence
    _tmp = match_string("/")
    unless _tmp
      self.pos = _save31
      break
    end
    _text_start = self.pos
    _tmp = apply('not_slash', :_not_slash)
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save31
      break
    end
    _tmp = match_string("/")
    unless _tmp
      self.pos = _save31
      break
    end
    @result = begin;  @g.reg(Regexp.new(text)) ; end
    _tmp = true
    unless _tmp
      self.pos = _save31
    end
    break
    end # end sequence

    return _tmp
  end

  # char = < /[a-zA-Z0-9]/ > { text }
  def _char

    _save32 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = scan(/\A(?-mix:[a-zA-Z0-9])/)
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save32
      break
    end
    @result = begin;  text ; end
    _tmp = true
    unless _tmp
      self.pos = _save32
    end
    break
    end # end sequence

    return _tmp
  end

  # char_range = "[" char:l "-" char:r "]" { @g.range(l,r) }
  def _char_range

    _save33 = self.pos
    while true # sequence
    _tmp = match_string("[")
    unless _tmp
      self.pos = _save33
      break
    end
    _tmp = apply('char', :_char)
    l = @result
    unless _tmp
      self.pos = _save33
      break
    end
    _tmp = match_string("-")
    unless _tmp
      self.pos = _save33
      break
    end
    _tmp = apply('char', :_char)
    r = @result
    unless _tmp
      self.pos = _save33
      break
    end
    _tmp = match_string("]")
    unless _tmp
      self.pos = _save33
      break
    end
    @result = begin;  @g.range(l,r) ; end
    _tmp = true
    unless _tmp
      self.pos = _save33
    end
    break
    end # end sequence

    return _tmp
  end

  # range_elem = < /([1-9][0-9]*)|\*/ > { text }
  def _range_elem

    _save34 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = scan(/\A(?-mix:([1-9][0-9]*)|\*)/)
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save34
      break
    end
    @result = begin;  text ; end
    _tmp = true
    unless _tmp
      self.pos = _save34
    end
    break
    end # end sequence

    return _tmp
  end

  # mult_range = "[" - range_elem:l - "," - range_elem:r - "]" { [l == "*" ? nil : l.to_i, r == "*" ? nil : r.to_i] }
  def _mult_range

    _save35 = self.pos
    while true # sequence
    _tmp = match_string("[")
    unless _tmp
      self.pos = _save35
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save35
      break
    end
    _tmp = apply('range_elem', :_range_elem)
    l = @result
    unless _tmp
      self.pos = _save35
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save35
      break
    end
    _tmp = match_string(",")
    unless _tmp
      self.pos = _save35
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save35
      break
    end
    _tmp = apply('range_elem', :_range_elem)
    r = @result
    unless _tmp
      self.pos = _save35
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save35
      break
    end
    _tmp = match_string("]")
    unless _tmp
      self.pos = _save35
      break
    end
    @result = begin;  [l == "*" ? nil : l.to_i, r == "*" ? nil : r.to_i] ; end
    _tmp = true
    unless _tmp
      self.pos = _save35
    end
    break
    end # end sequence

    return _tmp
  end

  # curly_block = curly
  def _curly_block
    _tmp = apply('curly', :_curly)
    return _tmp
  end

  # curly = "{" < (/[^{}]+/ | curly)* > "}" { @g.action(text) }
  def _curly

    _save36 = self.pos
    while true # sequence
    _tmp = match_string("{")
    unless _tmp
      self.pos = _save36
      break
    end
    _text_start = self.pos
    while true

    _save38 = self.pos
    while true # choice
    _tmp = scan(/\A(?-mix:[^{}]+)/)
    break if _tmp
    self.pos = _save38
    _tmp = apply('curly', :_curly)
    break if _tmp
    self.pos = _save38
    break
    end # end choice

    break unless _tmp
    end
    _tmp = true
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save36
      break
    end
    _tmp = match_string("}")
    unless _tmp
      self.pos = _save36
      break
    end
    @result = begin;  @g.action(text) ; end
    _tmp = true
    unless _tmp
      self.pos = _save36
    end
    break
    end # end sequence

    return _tmp
  end

  # value = (value:v ":" var:n { @g.t(v,n) } | value:v "?" { @g.maybe(v) } | value:v "+" { @g.many(v) } | value:v "*" { @g.kleene(v) } | value:v mult_range:r { @g.multiple(v, *r) } | "&" value:v { @g.andp(v) } | "!" value:v { @g.notp(v) } | "(" - expression:o - ")" { o } | "<" - expression:o - ">" { @g.collect(o) } | curly_block | "." { @g.dot } | var:name !(- "=") { @g.ref(name) } | char_range | regexp | string)
  def _value

    _save39 = self.pos
    while true # choice

    _save40 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save40
      break
    end
    _tmp = match_string(":")
    unless _tmp
      self.pos = _save40
      break
    end
    _tmp = apply('var', :_var)
    n = @result
    unless _tmp
      self.pos = _save40
      break
    end
    @result = begin;  @g.t(v,n) ; end
    _tmp = true
    unless _tmp
      self.pos = _save40
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39

    _save41 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save41
      break
    end
    _tmp = match_string("?")
    unless _tmp
      self.pos = _save41
      break
    end
    @result = begin;  @g.maybe(v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save41
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39

    _save42 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save42
      break
    end
    _tmp = match_string("+")
    unless _tmp
      self.pos = _save42
      break
    end
    @result = begin;  @g.many(v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save42
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39

    _save43 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save43
      break
    end
    _tmp = match_string("*")
    unless _tmp
      self.pos = _save43
      break
    end
    @result = begin;  @g.kleene(v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save43
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39

    _save44 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save44
      break
    end
    _tmp = apply('mult_range', :_mult_range)
    r = @result
    unless _tmp
      self.pos = _save44
      break
    end
    @result = begin;  @g.multiple(v, *r) ; end
    _tmp = true
    unless _tmp
      self.pos = _save44
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39

    _save45 = self.pos
    while true # sequence
    _tmp = match_string("&")
    unless _tmp
      self.pos = _save45
      break
    end
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save45
      break
    end
    @result = begin;  @g.andp(v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save45
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39

    _save46 = self.pos
    while true # sequence
    _tmp = match_string("!")
    unless _tmp
      self.pos = _save46
      break
    end
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save46
      break
    end
    @result = begin;  @g.notp(v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save46
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39

    _save47 = self.pos
    while true # sequence
    _tmp = match_string("(")
    unless _tmp
      self.pos = _save47
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save47
      break
    end
    _tmp = apply('expression', :_expression)
    o = @result
    unless _tmp
      self.pos = _save47
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save47
      break
    end
    _tmp = match_string(")")
    unless _tmp
      self.pos = _save47
      break
    end
    @result = begin;  o ; end
    _tmp = true
    unless _tmp
      self.pos = _save47
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39

    _save48 = self.pos
    while true # sequence
    _tmp = match_string("<")
    unless _tmp
      self.pos = _save48
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save48
      break
    end
    _tmp = apply('expression', :_expression)
    o = @result
    unless _tmp
      self.pos = _save48
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save48
      break
    end
    _tmp = match_string(">")
    unless _tmp
      self.pos = _save48
      break
    end
    @result = begin;  @g.collect(o) ; end
    _tmp = true
    unless _tmp
      self.pos = _save48
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39
    _tmp = apply('curly_block', :_curly_block)
    break if _tmp
    self.pos = _save39

    _save49 = self.pos
    while true # sequence
    _tmp = match_string(".")
    unless _tmp
      self.pos = _save49
      break
    end
    @result = begin;  @g.dot ; end
    _tmp = true
    unless _tmp
      self.pos = _save49
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39

    _save50 = self.pos
    while true # sequence
    _tmp = apply('var', :_var)
    name = @result
    unless _tmp
      self.pos = _save50
      break
    end
    _save51 = self.pos

    _save52 = self.pos
    while true # sequence
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save52
      break
    end
    _tmp = match_string("=")
    unless _tmp
      self.pos = _save52
    end
    break
    end # end sequence

    self.pos = _save51
    _tmp = _tmp ? nil : true
    unless _tmp
      self.pos = _save50
      break
    end
    @result = begin;  @g.ref(name) ; end
    _tmp = true
    unless _tmp
      self.pos = _save50
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save39
    _tmp = apply('char_range', :_char_range)
    break if _tmp
    self.pos = _save39
    _tmp = apply('regexp', :_regexp)
    break if _tmp
    self.pos = _save39
    _tmp = apply('string', :_string)
    break if _tmp
    self.pos = _save39
    break
    end # end choice

    return _tmp
  end

  # spaces = (space | comment)+
  def _spaces
    _save53 = self.pos

    _save54 = self.pos
    while true # choice
    _tmp = apply('space', :_space)
    break if _tmp
    self.pos = _save54
    _tmp = apply('comment', :_comment)
    break if _tmp
    self.pos = _save54
    break
    end # end choice

    if _tmp
      while true
    
    _save55 = self.pos
    while true # choice
    _tmp = apply('space', :_space)
    break if _tmp
    self.pos = _save55
    _tmp = apply('comment', :_comment)
    break if _tmp
    self.pos = _save55
    break
    end # end choice

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save53
    end
    return _tmp
  end

  # values = (values:s spaces value:v { @g.seq(s, v) } | value:l spaces value:r { @g.seq(l, r) } | value)
  def _values

    _save56 = self.pos
    while true # choice

    _save57 = self.pos
    while true # sequence
    _tmp = apply('values', :_values)
    s = @result
    unless _tmp
      self.pos = _save57
      break
    end
    _tmp = apply('spaces', :_spaces)
    unless _tmp
      self.pos = _save57
      break
    end
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save57
      break
    end
    @result = begin;  @g.seq(s, v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save57
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save56

    _save58 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    l = @result
    unless _tmp
      self.pos = _save58
      break
    end
    _tmp = apply('spaces', :_spaces)
    unless _tmp
      self.pos = _save58
      break
    end
    _tmp = apply('value', :_value)
    r = @result
    unless _tmp
      self.pos = _save58
      break
    end
    @result = begin;  @g.seq(l, r) ; end
    _tmp = true
    unless _tmp
      self.pos = _save58
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save56
    _tmp = apply('value', :_value)
    break if _tmp
    self.pos = _save56
    break
    end # end choice

    return _tmp
  end

  # choose_cont = - "|" - values:v { v }
  def _choose_cont

    _save59 = self.pos
    while true # sequence
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save59
      break
    end
    _tmp = match_string("|")
    unless _tmp
      self.pos = _save59
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save59
      break
    end
    _tmp = apply('values', :_values)
    v = @result
    unless _tmp
      self.pos = _save59
      break
    end
    @result = begin;  v ; end
    _tmp = true
    unless _tmp
      self.pos = _save59
    end
    break
    end # end sequence

    return _tmp
  end

  # expression = (values:v choose_cont+:alts { @g.any(v, *alts) } | values)
  def _expression

    _save60 = self.pos
    while true # choice

    _save61 = self.pos
    while true # sequence
    _tmp = apply('values', :_values)
    v = @result
    unless _tmp
      self.pos = _save61
      break
    end
    _save62 = self.pos
    _ary = []
    _tmp = apply('choose_cont', :_choose_cont)
    if _tmp
      _ary << @result
      while true
        _tmp = apply('choose_cont', :_choose_cont)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
    else
      self.pos = _save62
    end
    alts = @result
    unless _tmp
      self.pos = _save61
      break
    end
    @result = begin;  @g.any(v, *alts) ; end
    _tmp = true
    unless _tmp
      self.pos = _save61
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save60
    _tmp = apply('values', :_values)
    break if _tmp
    self.pos = _save60
    break
    end # end choice

    return _tmp
  end

  # statement = (- var:v - "=" - expression:o { @g.set(v, o) } | - "%%" - curly:act { @g.add_setup act })
  def _statement

    _save63 = self.pos
    while true # choice

    _save64 = self.pos
    while true # sequence
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save64
      break
    end
    _tmp = apply('var', :_var)
    v = @result
    unless _tmp
      self.pos = _save64
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save64
      break
    end
    _tmp = match_string("=")
    unless _tmp
      self.pos = _save64
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save64
      break
    end
    _tmp = apply('expression', :_expression)
    o = @result
    unless _tmp
      self.pos = _save64
      break
    end
    @result = begin;  @g.set(v, o) ; end
    _tmp = true
    unless _tmp
      self.pos = _save64
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save63

    _save65 = self.pos
    while true # sequence
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save65
      break
    end
    _tmp = match_string("%%")
    unless _tmp
      self.pos = _save65
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save65
      break
    end
    _tmp = apply('curly', :_curly)
    act = @result
    unless _tmp
      self.pos = _save65
      break
    end
    @result = begin;  @g.add_setup act ; end
    _tmp = true
    unless _tmp
      self.pos = _save65
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save63
    break
    end # end choice

    return _tmp
  end

  # statements = statement (- statements)?
  def _statements

    _save66 = self.pos
    while true # sequence
    _tmp = apply('statement', :_statement)
    unless _tmp
      self.pos = _save66
      break
    end
    _save67 = self.pos

    _save68 = self.pos
    while true # sequence
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save68
      break
    end
    _tmp = apply('statements', :_statements)
    unless _tmp
      self.pos = _save68
    end
    break
    end # end sequence

    unless _tmp
      _tmp = true
      self.pos = _save67
    end
    unless _tmp
      self.pos = _save66
    end
    break
    end # end sequence

    return _tmp
  end

  # eof = !.
  def _eof
    _save69 = self.pos
    _tmp = get_byte
    self.pos = _save69
    _tmp = _tmp ? nil : true
    return _tmp
  end

  # root = statements - "\n"? eof
  def _root

    _save70 = self.pos
    while true # sequence
    _tmp = apply('statements', :_statements)
    unless _tmp
      self.pos = _save70
      break
    end
    _tmp = apply('-', :__hyphen_)
    unless _tmp
      self.pos = _save70
      break
    end
    _save71 = self.pos
    _tmp = match_string("\n")
    unless _tmp
      _tmp = true
      self.pos = _save71
    end
    unless _tmp
      self.pos = _save70
      break
    end
    _tmp = apply('eof', :_eof)
    unless _tmp
      self.pos = _save70
    end
    break
    end # end sequence

    return _tmp
  end
end
