class KPeg::FormatParser < KPeg::CompiledParser
  def _sp
    while true
    _tmp = match_string(" ")
    break unless _tmp
    end
    _tmp = true
    return _tmp
  end
  def _bsp
    while true

    _save2 = self.pos
    while true # choice
    _tmp = match_string(" ")
    break if _tmp
    self.pos = _save2
    _tmp = match_string("\n")
    break if _tmp
    self.pos = _save2
    break
    end # end choice

    break unless _tmp
    end
    _tmp = true
    return _tmp
  end
  def _var

    _save3 = self.pos
    while true # sequence
    _text_start = self.pos

    _save4 = self.pos
    while true # choice
    _tmp = match_string("-")
    break if _tmp
    self.pos = _save4
    _tmp = scan(/\A(?-mix:[a-zA-Z][\-_a-zA-Z0-9]*)/)
    break if _tmp
    self.pos = _save4
    break
    end # end choice

    if _tmp
      set_text(_text_start)
    end
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

    return _tmp
  end
  def _dbl_escapes

    _save5 = self.pos
    while true # choice

    _save6 = self.pos
    while true # sequence
    _tmp = match_string("\\\"")
    unless _tmp
      self.pos = _save6
      break
    end
    @result = begin;  '"' ; end
    _tmp = true
    unless _tmp
      self.pos = _save6
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save5

    _save7 = self.pos
    while true # sequence
    _tmp = match_string("\\n")
    unless _tmp
      self.pos = _save7
      break
    end
    @result = begin;  "\n" ; end
    _tmp = true
    unless _tmp
      self.pos = _save7
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save5

    _save8 = self.pos
    while true # sequence
    _tmp = match_string("\\t")
    unless _tmp
      self.pos = _save8
      break
    end
    @result = begin;  "\t" ; end
    _tmp = true
    unless _tmp
      self.pos = _save8
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save5

    _save9 = self.pos
    while true # sequence
    _tmp = match_string("\\\\")
    unless _tmp
      self.pos = _save9
      break
    end
    @result = begin;  "\\" ; end
    _tmp = true
    unless _tmp
      self.pos = _save9
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save5
    break
    end # end choice

    return _tmp
  end
  def _dbl_seq

    _save10 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = scan(/\A(?-mix:[^\\"]+)/)
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save10
      break
    end
    @result = begin;  text ; end
    _tmp = true
    unless _tmp
      self.pos = _save10
    end
    break
    end # end sequence

    return _tmp
  end
  def _dbl_not_quote

    _save11 = self.pos
    while true # sequence
    _save12 = self.pos
    _ary = []

    _save13 = self.pos
    while true # choice
    _tmp = apply('dbl_escapes', :_dbl_escapes)
    s = @result
    break if _tmp
    self.pos = _save13
    _tmp = apply('dbl_seq', :_dbl_seq)
    s = @result
    break if _tmp
    self.pos = _save13
    break
    end # end choice

    if _tmp
      _ary << @result
      while true
    
    _save14 = self.pos
    while true # choice
    _tmp = apply('dbl_escapes', :_dbl_escapes)
    s = @result
    break if _tmp
    self.pos = _save14
    _tmp = apply('dbl_seq', :_dbl_seq)
    s = @result
    break if _tmp
    self.pos = _save14
    break
    end # end choice

        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
    else
      self.pos = _save12
    end
    ary = @result
    unless _tmp
      self.pos = _save11
      break
    end
    @result = begin;  ary ; end
    _tmp = true
    unless _tmp
      self.pos = _save11
    end
    break
    end # end sequence

    return _tmp
  end
  def _dbl_string

    _save15 = self.pos
    while true # sequence
    _tmp = match_string("\"")
    unless _tmp
      self.pos = _save15
      break
    end
    _tmp = apply('dbl_not_quote', :_dbl_not_quote)
    s = @result
    unless _tmp
      self.pos = _save15
      break
    end
    _tmp = match_string("\"")
    unless _tmp
      self.pos = _save15
      break
    end
    @result = begin;  @g.str(s.join) ; end
    _tmp = true
    unless _tmp
      self.pos = _save15
    end
    break
    end # end sequence

    return _tmp
  end
  def _sgl_escape_quote

    _save16 = self.pos
    while true # sequence
    _tmp = match_string("\\'")
    unless _tmp
      self.pos = _save16
      break
    end
    @result = begin;  "'" ; end
    _tmp = true
    unless _tmp
      self.pos = _save16
    end
    break
    end # end sequence

    return _tmp
  end
  def _sgl_seq

    _save17 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = scan(/\A(?-mix:[^'])/)
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save17
      break
    end
    @result = begin;  text ; end
    _tmp = true
    unless _tmp
      self.pos = _save17
    end
    break
    end # end sequence

    return _tmp
  end
  def _sgl_not_quote

    _save18 = self.pos
    while true # sequence
    _save19 = self.pos
    _ary = []

    _save20 = self.pos
    while true # choice
    _tmp = apply('sgl_escape_quote', :_sgl_escape_quote)
    break if _tmp
    self.pos = _save20
    _tmp = apply('sql_seq', :_sql_seq)
    break if _tmp
    self.pos = _save20
    break
    end # end choice

    if _tmp
      _ary << @result
      while true
    
    _save21 = self.pos
    while true # choice
    _tmp = apply('sgl_escape_quote', :_sgl_escape_quote)
    break if _tmp
    self.pos = _save21
    _tmp = apply('sql_seq', :_sql_seq)
    break if _tmp
    self.pos = _save21
    break
    end # end choice

        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
    else
      self.pos = _save19
    end
    segs = @result
    unless _tmp
      self.pos = _save18
      break
    end
    @result = begin;  segs.join ; end
    _tmp = true
    unless _tmp
      self.pos = _save18
    end
    break
    end # end sequence

    return _tmp
  end
  def _sgl_string

    _save22 = self.pos
    while true # sequence
    _tmp = match_string("'")
    unless _tmp
      self.pos = _save22
      break
    end
    _tmp = apply('sgl_not_quote', :_sgl_not_quote)
    s = @result
    unless _tmp
      self.pos = _save22
      break
    end
    _tmp = match_string("'")
    unless _tmp
      self.pos = _save22
      break
    end
    @result = begin;  @g.str(s) ; end
    _tmp = true
    unless _tmp
      self.pos = _save22
    end
    break
    end # end sequence

    return _tmp
  end
  def _string

    _save23 = self.pos
    while true # choice
    _tmp = apply('dbl_string', :_dbl_string)
    break if _tmp
    self.pos = _save23
    _tmp = apply('sgl_string', :_sgl_string)
    break if _tmp
    self.pos = _save23
    break
    end # end choice

    return _tmp
  end
  def _not_slash
    _save24 = self.pos

    _save25 = self.pos
    while true # choice
    _tmp = match_string("\\/")
    break if _tmp
    self.pos = _save25
    _tmp = scan(/\A(?-mix:[^\/])/)
    break if _tmp
    self.pos = _save25
    break
    end # end choice

    if _tmp
      while true
    
    _save26 = self.pos
    while true # choice
    _tmp = match_string("\\/")
    break if _tmp
    self.pos = _save26
    _tmp = scan(/\A(?-mix:[^\/])/)
    break if _tmp
    self.pos = _save26
    break
    end # end choice

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save24
    end
    return _tmp
  end
  def _regexp

    _save27 = self.pos
    while true # sequence
    _tmp = match_string("/")
    unless _tmp
      self.pos = _save27
      break
    end
    _text_start = self.pos
    _tmp = apply('not_slash', :_not_slash)
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save27
      break
    end
    _tmp = match_string("/")
    unless _tmp
      self.pos = _save27
      break
    end
    @result = begin;  @g.reg(Regexp.new(text)) ; end
    _tmp = true
    unless _tmp
      self.pos = _save27
    end
    break
    end # end sequence

    return _tmp
  end
  def _char

    _save28 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = scan(/\A(?-mix:[a-zA-Z0-9])/)
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save28
      break
    end
    @result = begin;  text ; end
    _tmp = true
    unless _tmp
      self.pos = _save28
    end
    break
    end # end sequence

    return _tmp
  end
  def _char_range

    _save29 = self.pos
    while true # sequence
    _tmp = match_string("[")
    unless _tmp
      self.pos = _save29
      break
    end
    _tmp = apply('char', :_char)
    l = @result
    unless _tmp
      self.pos = _save29
      break
    end
    _tmp = match_string("-")
    unless _tmp
      self.pos = _save29
      break
    end
    _tmp = apply('char', :_char)
    r = @result
    unless _tmp
      self.pos = _save29
      break
    end
    _tmp = match_string("]")
    unless _tmp
      self.pos = _save29
      break
    end
    @result = begin;  @g.range(l,r) ; end
    _tmp = true
    unless _tmp
      self.pos = _save29
    end
    break
    end # end sequence

    return _tmp
  end
  def _range_elem

    _save30 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = scan(/\A(?-mix:([1-9][0-9]*)|\*)/)
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save30
      break
    end
    @result = begin;  text ; end
    _tmp = true
    unless _tmp
      self.pos = _save30
    end
    break
    end # end sequence

    return _tmp
  end
  def _mult_range

    _save31 = self.pos
    while true # sequence
    _tmp = match_string("[")
    unless _tmp
      self.pos = _save31
      break
    end
    _tmp = apply('sp', :_sp)
    unless _tmp
      self.pos = _save31
      break
    end
    _tmp = apply('range_elem', :_range_elem)
    l = @result
    unless _tmp
      self.pos = _save31
      break
    end
    _tmp = apply('sp', :_sp)
    unless _tmp
      self.pos = _save31
      break
    end
    _tmp = match_string(",")
    unless _tmp
      self.pos = _save31
      break
    end
    _tmp = apply('sp', :_sp)
    unless _tmp
      self.pos = _save31
      break
    end
    _tmp = apply('range_elem', :_range_elem)
    r = @result
    unless _tmp
      self.pos = _save31
      break
    end
    _tmp = apply('sp', :_sp)
    unless _tmp
      self.pos = _save31
      break
    end
    _tmp = match_string("]")
    unless _tmp
      self.pos = _save31
      break
    end
    @result = begin;  [l,r] ; end
    _tmp = true
    unless _tmp
      self.pos = _save31
    end
    break
    end # end sequence

    return _tmp
  end
  def _curly_block
    _tmp = apply('curly', :_curly)
    return _tmp
  end
  def _curly

    _save32 = self.pos
    while true # sequence
    _tmp = match_string("{")
    unless _tmp
      self.pos = _save32
      break
    end
    _text_start = self.pos
    while true

    _save34 = self.pos
    while true # choice
    _tmp = scan(/\A(?-mix:[^{}]+)/)
    break if _tmp
    self.pos = _save34
    _tmp = apply('curly', :_curly)
    break if _tmp
    self.pos = _save34
    break
    end # end choice

    break unless _tmp
    end
    _tmp = true
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save32
      break
    end
    _tmp = match_string("}")
    unless _tmp
      self.pos = _save32
      break
    end
    @result = begin;  @g.action(text) ; end
    _tmp = true
    unless _tmp
      self.pos = _save32
    end
    break
    end # end sequence

    return _tmp
  end
  def _value

    _save35 = self.pos
    while true # choice

    _save36 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save36
      break
    end
    _tmp = match_string(":")
    unless _tmp
      self.pos = _save36
      break
    end
    _tmp = apply('var', :_var)
    n = @result
    unless _tmp
      self.pos = _save36
      break
    end
    @result = begin;  @g.t(v,n) ; end
    _tmp = true
    unless _tmp
      self.pos = _save36
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35

    _save37 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save37
      break
    end
    _tmp = match_string("?")
    unless _tmp
      self.pos = _save37
      break
    end
    @result = begin;  @g.maybe(v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save37
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35

    _save38 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save38
      break
    end
    _tmp = match_string("+")
    unless _tmp
      self.pos = _save38
      break
    end
    @result = begin;  @g.many(v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save38
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35

    _save39 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save39
      break
    end
    _tmp = match_string("*")
    unless _tmp
      self.pos = _save39
      break
    end
    @result = begin;  @g.kleene(v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save39
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35

    _save40 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save40
      break
    end
    _tmp = apply('mult_range', :_mult_range)
    r = @result
    unless _tmp
      self.pos = _save40
      break
    end
    @result = begin;  @g.multiple(v, *r) ; end
    _tmp = true
    unless _tmp
      self.pos = _save40
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35

    _save41 = self.pos
    while true # sequence
    _tmp = match_string("&")
    unless _tmp
      self.pos = _save41
      break
    end
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save41
      break
    end
    @result = begin;  @g.andp(v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save41
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35

    _save42 = self.pos
    while true # sequence
    _tmp = match_string("!")
    unless _tmp
      self.pos = _save42
      break
    end
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save42
      break
    end
    @result = begin;  @g.notp(v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save42
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35

    _save43 = self.pos
    while true # sequence
    _tmp = match_string("(")
    unless _tmp
      self.pos = _save43
      break
    end
    _tmp = apply('bsp', :_bsp)
    unless _tmp
      self.pos = _save43
      break
    end
    _tmp = apply('expression', :_expression)
    o = @result
    unless _tmp
      self.pos = _save43
      break
    end
    _tmp = apply('bsp', :_bsp)
    unless _tmp
      self.pos = _save43
      break
    end
    _tmp = match_string(")")
    unless _tmp
      self.pos = _save43
      break
    end
    @result = begin;  o ; end
    _tmp = true
    unless _tmp
      self.pos = _save43
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35

    _save44 = self.pos
    while true # sequence
    _tmp = match_string("<")
    unless _tmp
      self.pos = _save44
      break
    end
    _tmp = apply('bsp', :_bsp)
    unless _tmp
      self.pos = _save44
      break
    end
    _tmp = apply('expression', :_expression)
    o = @result
    unless _tmp
      self.pos = _save44
      break
    end
    _tmp = apply('bsp', :_bsp)
    unless _tmp
      self.pos = _save44
      break
    end
    _tmp = match_string(">")
    unless _tmp
      self.pos = _save44
      break
    end
    @result = begin;  @g.collect(o) ; end
    _tmp = true
    unless _tmp
      self.pos = _save44
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35
    _tmp = apply('curly_block', :_curly_block)
    break if _tmp
    self.pos = _save35

    _save45 = self.pos
    while true # sequence
    _tmp = match_string(".")
    unless _tmp
      self.pos = _save45
      break
    end
    @result = begin;  @g.dot ; end
    _tmp = true
    unless _tmp
      self.pos = _save45
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35

    _save46 = self.pos
    while true # sequence
    _tmp = apply('var', :_var)
    name = @result
    unless _tmp
      self.pos = _save46
      break
    end
    _save47 = self.pos

    _save48 = self.pos
    while true # sequence
    _tmp = apply('sp', :_sp)
    unless _tmp
      self.pos = _save48
      break
    end
    _tmp = match_string("=")
    unless _tmp
      self.pos = _save48
    end
    break
    end # end sequence

    self.pos = _save47
    _tmp = _tmp ? nil : true
    unless _tmp
      self.pos = _save46
      break
    end
    @result = begin;  @g.ref(name) ; end
    _tmp = true
    unless _tmp
      self.pos = _save46
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save35
    _tmp = apply('char_range', :_char_range)
    break if _tmp
    self.pos = _save35
    _tmp = apply('regexp', :_regexp)
    break if _tmp
    self.pos = _save35
    _tmp = apply('string', :_string)
    break if _tmp
    self.pos = _save35
    break
    end # end choice

    return _tmp
  end
  def _spaces
    _save49 = self.pos

    _save50 = self.pos
    while true # choice
    _tmp = match_string(" ")
    break if _tmp
    self.pos = _save50
    _tmp = match_string("\n")
    break if _tmp
    self.pos = _save50
    break
    end # end choice

    if _tmp
      while true
    
    _save51 = self.pos
    while true # choice
    _tmp = match_string(" ")
    break if _tmp
    self.pos = _save51
    _tmp = match_string("\n")
    break if _tmp
    self.pos = _save51
    break
    end # end choice

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save49
    end
    return _tmp
  end
  def _values

    _save52 = self.pos
    while true # choice

    _save53 = self.pos
    while true # sequence
    _tmp = apply('values', :_values)
    s = @result
    unless _tmp
      self.pos = _save53
      break
    end
    _tmp = apply('spaces', :_spaces)
    unless _tmp
      self.pos = _save53
      break
    end
    _tmp = apply('value', :_value)
    v = @result
    unless _tmp
      self.pos = _save53
      break
    end
    @result = begin;  @g.seq(s, v) ; end
    _tmp = true
    unless _tmp
      self.pos = _save53
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save52

    _save54 = self.pos
    while true # sequence
    _tmp = apply('value', :_value)
    l = @result
    unless _tmp
      self.pos = _save54
      break
    end
    _tmp = apply('spaces', :_spaces)
    unless _tmp
      self.pos = _save54
      break
    end
    _tmp = apply('value', :_value)
    r = @result
    unless _tmp
      self.pos = _save54
      break
    end
    @result = begin;  @g.seq(l, r) ; end
    _tmp = true
    unless _tmp
      self.pos = _save54
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save52
    _tmp = apply('value', :_value)
    break if _tmp
    self.pos = _save52
    break
    end # end choice

    return _tmp
  end
  def _choose_cont

    _save55 = self.pos
    while true # sequence
    _tmp = apply('bsp', :_bsp)
    unless _tmp
      self.pos = _save55
      break
    end
    _tmp = match_string("|")
    unless _tmp
      self.pos = _save55
      break
    end
    _tmp = apply('bsp', :_bsp)
    unless _tmp
      self.pos = _save55
      break
    end
    _tmp = apply('values', :_values)
    v = @result
    unless _tmp
      self.pos = _save55
      break
    end
    @result = begin;  v ; end
    _tmp = true
    unless _tmp
      self.pos = _save55
    end
    break
    end # end sequence

    return _tmp
  end
  def _expression

    _save56 = self.pos
    while true # choice

    _save57 = self.pos
    while true # sequence
    _tmp = apply('values', :_values)
    v = @result
    unless _tmp
      self.pos = _save57
      break
    end
    _save58 = self.pos
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
      self.pos = _save58
    end
    alts = @result
    unless _tmp
      self.pos = _save57
      break
    end
    @result = begin;  @g.any(v, *alts) ; end
    _tmp = true
    unless _tmp
      self.pos = _save57
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save56
    _tmp = apply('values', :_values)
    break if _tmp
    self.pos = _save56
    break
    end # end choice

    return _tmp
  end
  def _assignment

    _save59 = self.pos
    while true # sequence
    _tmp = apply('sp', :_sp)
    unless _tmp
      self.pos = _save59
      break
    end
    _tmp = apply('var', :_var)
    v = @result
    unless _tmp
      self.pos = _save59
      break
    end
    _tmp = apply('sp', :_sp)
    unless _tmp
      self.pos = _save59
      break
    end
    _tmp = match_string("=")
    unless _tmp
      self.pos = _save59
      break
    end
    _tmp = apply('sp', :_sp)
    unless _tmp
      self.pos = _save59
      break
    end
    _tmp = apply('expression', :_expression)
    o = @result
    unless _tmp
      self.pos = _save59
      break
    end
    @result = begin;  @g.set(v, o) ; end
    _tmp = true
    unless _tmp
      self.pos = _save59
    end
    break
    end # end sequence

    return _tmp
  end
  def _assignments

    _save60 = self.pos
    while true # sequence
    _tmp = apply('assignment', :_assignment)
    unless _tmp
      self.pos = _save60
      break
    end
    _save61 = self.pos

    _save62 = self.pos
    while true # sequence
    _tmp = apply('bsp', :_bsp)
    unless _tmp
      self.pos = _save62
      break
    end
    _tmp = apply('assignments', :_assignments)
    unless _tmp
      self.pos = _save62
    end
    break
    end # end sequence

    unless _tmp
      _tmp = true
      self.pos = _save61
    end
    unless _tmp
      self.pos = _save60
    end
    break
    end # end sequence

    return _tmp
  end
  def _root

    _save63 = self.pos
    while true # sequence
    _tmp = apply('assignments', :_assignments)
    unless _tmp
      self.pos = _save63
      break
    end
    _tmp = apply('sp', :_sp)
    unless _tmp
      self.pos = _save63
      break
    end
    _save64 = self.pos
    _tmp = match_string("\n")
    unless _tmp
      _tmp = true
      self.pos = _save64
    end
    unless _tmp
      self.pos = _save63
    end
    break
    end # end sequence

    return _tmp
  end
end
