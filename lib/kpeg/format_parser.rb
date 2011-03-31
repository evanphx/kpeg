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
    set_failed_rule :_eol unless _tmp
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

  # curly = "{" < (/[^{}]+/ | curly)* > "}" { @g.action(text) }
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
    _tmp = scan(/\A(?-mix:[^{}]+)/)
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

  # value = (value:v ":" var:n { @g.t(v,n) } | value:v "?" { @g.maybe(v) } | value:v "+" { @g.many(v) } | value:v "*" { @g.kleene(v) } | value:v mult_range:r { @g.multiple(v, *r) } | "&" value:v { @g.andp(v) } | "!" value:v { @g.notp(v) } | "(" - expression:o - ")" { o } | "<" - expression:o - ">" { @g.collect(o) } | curly_block | "." { @g.dot } | "@" var:name !(- "=") { @g.invoke(name) } | "^" var:name < nested_paren? > { @g.foreign_invoke("parent", name, text) } | "%" var:gram "." var:name < nested_paren? > { @g.foreign_invoke(gram, name, text) } | var:name < nested_paren? > !(- "=") { text.empty? ? @g.ref(name) : @g.invoke(name, text) } | char_range | regexp | string)
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
    _tmp = match_string("<")
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
    @result = begin;  @g.collect(o) ; end
    _tmp = true
    unless _tmp
      self.pos = _save9
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    _tmp = apply(:_curly_block)
    break if _tmp
    self.pos = _save

    _save10 = self.pos
    while true # sequence
    _tmp = match_string(".")
    unless _tmp
      self.pos = _save10
      break
    end
    @result = begin;  @g.dot ; end
    _tmp = true
    unless _tmp
      self.pos = _save10
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save

    _save11 = self.pos
    while true # sequence
    _tmp = match_string("@")
    unless _tmp
      self.pos = _save11
      break
    end
    _tmp = apply(:_var)
    name = @result
    unless _tmp
      self.pos = _save11
      break
    end
    _save12 = self.pos

    _save13 = self.pos
    while true # sequence
    _tmp = apply(:__hyphen_)
    unless _tmp
      self.pos = _save13
      break
    end
    _tmp = match_string("=")
    unless _tmp
      self.pos = _save13
    end
    break
    end # end sequence

    _tmp = _tmp ? nil : true
    self.pos = _save12
    unless _tmp
      self.pos = _save11
      break
    end
    @result = begin;  @g.invoke(name) ; end
    _tmp = true
    unless _tmp
      self.pos = _save11
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save

    _save14 = self.pos
    while true # sequence
    _tmp = match_string("^")
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
    _text_start = self.pos
    _save15 = self.pos
    _tmp = apply(:_nested_paren)
    unless _tmp
      _tmp = true
      self.pos = _save15
    end
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save14
      break
    end
    @result = begin;  @g.foreign_invoke("parent", name, text) ; end
    _tmp = true
    unless _tmp
      self.pos = _save14
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save

    _save16 = self.pos
    while true # sequence
    _tmp = match_string("%")
    unless _tmp
      self.pos = _save16
      break
    end
    _tmp = apply(:_var)
    gram = @result
    unless _tmp
      self.pos = _save16
      break
    end
    _tmp = match_string(".")
    unless _tmp
      self.pos = _save16
      break
    end
    _tmp = apply(:_var)
    name = @result
    unless _tmp
      self.pos = _save16
      break
    end
    _text_start = self.pos
    _save17 = self.pos
    _tmp = apply(:_nested_paren)
    unless _tmp
      _tmp = true
      self.pos = _save17
    end
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save16
      break
    end
    @result = begin;  @g.foreign_invoke(gram, name, text) ; end
    _tmp = true
    unless _tmp
      self.pos = _save16
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save

    _save18 = self.pos
    while true # sequence
    _tmp = apply(:_var)
    name = @result
    unless _tmp
      self.pos = _save18
      break
    end
    _text_start = self.pos
    _save19 = self.pos
    _tmp = apply(:_nested_paren)
    unless _tmp
      _tmp = true
      self.pos = _save19
    end
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save18
      break
    end
    _save20 = self.pos

    _save21 = self.pos
    while true # sequence
    _tmp = apply(:__hyphen_)
    unless _tmp
      self.pos = _save21
      break
    end
    _tmp = match_string("=")
    unless _tmp
      self.pos = _save21
    end
    break
    end # end sequence

    _tmp = _tmp ? nil : true
    self.pos = _save20
    unless _tmp
      self.pos = _save18
      break
    end
    @result = begin;  text.empty? ? @g.ref(name) : @g.invoke(name, text) ; end
    _tmp = true
    unless _tmp
      self.pos = _save18
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

  # root = statements - "\n"? eof
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
    _tmp = match_string("\n")
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

  Rules = {}
  Rules[:_eol] = rule_info("eol", "\"\\n\"")
  Rules[:_comment] = rule_info("comment", "\"\#\" (!eol .)* eol")
  Rules[:_space] = rule_info("space", "(\" \" | \"\\t\" | eol)")
  Rules[:__hyphen_] = rule_info("-", "(space | comment)*")
  Rules[:_kleene] = rule_info("kleene", "\"*\"")
  Rules[:_var] = rule_info("var", "< (\"-\" | /[a-zA-Z][\\-_a-zA-Z0-9]*/) > { text }")
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
  Rules[:_curly] = rule_info("curly", "\"{\" < (/[^{}]+/ | curly)* > \"}\" { @g.action(text) }")
  Rules[:_nested_paren] = rule_info("nested_paren", "\"(\" (/[^()]+/ | nested_paren)* \")\"")
  Rules[:_value] = rule_info("value", "(value:v \":\" var:n { @g.t(v,n) } | value:v \"?\" { @g.maybe(v) } | value:v \"+\" { @g.many(v) } | value:v \"*\" { @g.kleene(v) } | value:v mult_range:r { @g.multiple(v, *r) } | \"&\" value:v { @g.andp(v) } | \"!\" value:v { @g.notp(v) } | \"(\" - expression:o - \")\" { o } | \"<\" - expression:o - \">\" { @g.collect(o) } | curly_block | \".\" { @g.dot } | \"@\" var:name !(- \"=\") { @g.invoke(name) } | \"^\" var:name < nested_paren? > { @g.foreign_invoke(\"parent\", name, text) } | \"%\" var:gram \".\" var:name < nested_paren? > { @g.foreign_invoke(gram, name, text) } | var:name < nested_paren? > !(- \"=\") { text.empty? ? @g.ref(name) : @g.invoke(name, text) } | char_range | regexp | string)")
  Rules[:_spaces] = rule_info("spaces", "(space | comment)+")
  Rules[:_values] = rule_info("values", "(values:s spaces value:v { @g.seq(s, v) } | value:l spaces value:r { @g.seq(l, r) } | value)")
  Rules[:_choose_cont] = rule_info("choose_cont", "- \"|\" - values:v { v }")
  Rules[:_expression] = rule_info("expression", "(values:v choose_cont+:alts { @g.any(v, *alts) } | values)")
  Rules[:_args] = rule_info("args", "(args:a \",\" - var:n - { a + [n] } | - var:n - { [n] })")
  Rules[:_statement] = rule_info("statement", "(- var:v \"(\" args:a \")\" - \"=\" - expression:o { @g.set(v, o, a) } | - var:v - \"=\" - expression:o { @g.set(v, o) } | - \"%\" var:name - \"=\" - < /[::A-Za-z0-9_]+/ > { @g.add_foreign_grammar(name, text) } | - \"%%\" - curly:act { @g.add_setup act } | - \"%%\" - var:name - \"=\" - < (!\"\\n\" .)+ > { @g.set_variable(name, text) })")
  Rules[:_statements] = rule_info("statements", "statement (- statements)?")
  Rules[:_eof] = rule_info("eof", "!.")
  Rules[:_root] = rule_info("root", "statements - \"\\n\"? eof")
end
