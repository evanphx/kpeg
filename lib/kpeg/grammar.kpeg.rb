class KPeg::FileGrammar < KPeg::CompiledGrammar
  def _sp
    puts "START sp @ #{show_pos}\n"
    while true
    _tmp = match_string(" ")
    break unless _tmp
    end
    _tmp = true
    if _tmp
      puts "   OK sp @ #{show_pos}\n"
    else
      puts " FAIL sp @ #{show_pos}\n"
    end
    return _tmp
  end
  def _bsp
    puts "START bsp @ #{show_pos}\n"
    while true

    _save2 = self.pos
    while true # choice
    _tmp = match_string(" ")
    break if _tmp
    self.pos = _save2
    _tmp = match_string("\n")
    break
    end # end choice

    break unless _tmp
    end
    _tmp = true
    if _tmp
      puts "   OK bsp @ #{show_pos}\n"
    else
      puts " FAIL bsp @ #{show_pos}\n"
    end
    return _tmp
  end
  def _var
    puts "START var @ #{show_pos}\n"

    _save3 = self.pos
    while true # sequence
    _text_start = self.pos

    _save4 = self.pos
    while true # choice
    _tmp = match_string("-")
    break if _tmp
    self.pos = _save4
    _tmp = scan(/\A(?-mix:[a-zA-Z][\-_a-zA-Z0-9]*)/)
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
    puts "   => " " text " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

    if _tmp
      puts "   OK var @ #{show_pos}\n"
    else
      puts " FAIL var @ #{show_pos}\n"
    end
    return _tmp
  end
  def _dbl_escapes
    puts "START dbl_escapes @ #{show_pos}\n"

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
    puts "   => " " '\"' " " => #{@result.inspect} \n"
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
    puts "   => " " \"\\n\" " " => #{@result.inspect} \n"
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
    puts "   => " " \"\\t\" " " => #{@result.inspect} \n"
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
    puts "   => " " \"\\\\\" " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save9
    end
    break
    end # end sequence

    break
    end # end choice

    if _tmp
      puts "   OK dbl_escapes @ #{show_pos}\n"
    else
      puts " FAIL dbl_escapes @ #{show_pos}\n"
    end
    return _tmp
  end
  def _dbl_seq
    puts "START dbl_seq @ #{show_pos}\n"

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
    puts "   => " " text " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save10
    end
    break
    end # end sequence

    if _tmp
      puts "   OK dbl_seq @ #{show_pos}\n"
    else
      puts " FAIL dbl_seq @ #{show_pos}\n"
    end
    return _tmp
  end
  def _dbl_not_quote
    puts "START dbl_not_quote @ #{show_pos}\n"

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
    puts "   => " " ary " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save11
    end
    break
    end # end sequence

    if _tmp
      puts "   OK dbl_not_quote @ #{show_pos}\n"
    else
      puts " FAIL dbl_not_quote @ #{show_pos}\n"
    end
    return _tmp
  end
  def _dbl_string
    puts "START dbl_string @ #{show_pos}\n"

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
    puts "   => " " @g.str(s.join) " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save15
    end
    break
    end # end sequence

    if _tmp
      puts "   OK dbl_string @ #{show_pos}\n"
    else
      puts " FAIL dbl_string @ #{show_pos}\n"
    end
    return _tmp
  end
  def _sgl_escape_quote
    puts "START sgl_escape_quote @ #{show_pos}\n"

    _save16 = self.pos
    while true # sequence
    _tmp = match_string("\\'")
    unless _tmp
      self.pos = _save16
      break
    end
    @result = begin;  "'" ; end
    puts "   => " " \"'\" " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save16
    end
    break
    end # end sequence

    if _tmp
      puts "   OK sgl_escape_quote @ #{show_pos}\n"
    else
      puts " FAIL sgl_escape_quote @ #{show_pos}\n"
    end
    return _tmp
  end
  def _sgl_seq
    puts "START sgl_seq @ #{show_pos}\n"

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
    puts "   => " " text " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save17
    end
    break
    end # end sequence

    if _tmp
      puts "   OK sgl_seq @ #{show_pos}\n"
    else
      puts " FAIL sgl_seq @ #{show_pos}\n"
    end
    return _tmp
  end
  def _sgl_not_quote
    puts "START sgl_not_quote @ #{show_pos}\n"

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
    puts "   => " " segs.join " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save18
    end
    break
    end # end sequence

    if _tmp
      puts "   OK sgl_not_quote @ #{show_pos}\n"
    else
      puts " FAIL sgl_not_quote @ #{show_pos}\n"
    end
    return _tmp
  end
  def _sgl_string
    puts "START sgl_string @ #{show_pos}\n"

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
    puts "   => " " @g.str(s) " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save22
    end
    break
    end # end sequence

    if _tmp
      puts "   OK sgl_string @ #{show_pos}\n"
    else
      puts " FAIL sgl_string @ #{show_pos}\n"
    end
    return _tmp
  end
  def _string
    puts "START string @ #{show_pos}\n"

    _save23 = self.pos
    while true # choice
    _tmp = apply('dbl_string', :_dbl_string)
    break if _tmp
    self.pos = _save23
    _tmp = apply('sgl_string', :_sgl_string)
    break
    end # end choice

    if _tmp
      puts "   OK string @ #{show_pos}\n"
    else
      puts " FAIL string @ #{show_pos}\n"
    end
    return _tmp
  end
  def _not_slash
    puts "START not_slash @ #{show_pos}\n"
    _save24 = self.pos

    _save25 = self.pos
    while true # choice
    _tmp = match_string("\\/")
    break if _tmp
    self.pos = _save25
    _tmp = scan(/\A(?-mix:[^\/])/)
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
    break
    end # end choice

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save24
    end
    if _tmp
      puts "   OK not_slash @ #{show_pos}\n"
    else
      puts " FAIL not_slash @ #{show_pos}\n"
    end
    return _tmp
  end
  def _regexp
    puts "START regexp @ #{show_pos}\n"

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
    puts "   => " " @g.reg(Regexp.new(text)) " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save27
    end
    break
    end # end sequence

    if _tmp
      puts "   OK regexp @ #{show_pos}\n"
    else
      puts " FAIL regexp @ #{show_pos}\n"
    end
    return _tmp
  end
  def _char
    puts "START char @ #{show_pos}\n"

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
    puts "   => " " text " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save28
    end
    break
    end # end sequence

    if _tmp
      puts "   OK char @ #{show_pos}\n"
    else
      puts " FAIL char @ #{show_pos}\n"
    end
    return _tmp
  end
  def _char_range
    puts "START char_range @ #{show_pos}\n"

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
    puts "   => " " @g.range(l,r) " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save29
    end
    break
    end # end sequence

    if _tmp
      puts "   OK char_range @ #{show_pos}\n"
    else
      puts " FAIL char_range @ #{show_pos}\n"
    end
    return _tmp
  end
  def _range_elem
    puts "START range_elem @ #{show_pos}\n"

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
    puts "   => " " text " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save30
    end
    break
    end # end sequence

    if _tmp
      puts "   OK range_elem @ #{show_pos}\n"
    else
      puts " FAIL range_elem @ #{show_pos}\n"
    end
    return _tmp
  end
  def _mult_range
    puts "START mult_range @ #{show_pos}\n"

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
    puts "   => " " [l,r] " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save31
    end
    break
    end # end sequence

    if _tmp
      puts "   OK mult_range @ #{show_pos}\n"
    else
      puts " FAIL mult_range @ #{show_pos}\n"
    end
    return _tmp
  end
  def _curly_block
    puts "START curly_block @ #{show_pos}\n"
    _tmp = apply('curly', :_curly)
    if _tmp
      puts "   OK curly_block @ #{show_pos}\n"
    else
      puts " FAIL curly_block @ #{show_pos}\n"
    end
    return _tmp
  end
  def _curly
    puts "START curly @ #{show_pos}\n"

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
    puts "   => " " @g.action(text) " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save32
    end
    break
    end # end sequence

    if _tmp
      puts "   OK curly @ #{show_pos}\n"
    else
      puts " FAIL curly @ #{show_pos}\n"
    end
    return _tmp
  end
  def _value
    puts "START value @ #{show_pos}\n"

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
    puts "   => " " @g.t(v,n) " " => #{@result.inspect} \n"
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
    puts "   => " " @g.maybe(v) " " => #{@result.inspect} \n"
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
    puts "   => " " @g.many(v) " " => #{@result.inspect} \n"
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
    puts "   => " " @g.kleene(v) " " => #{@result.inspect} \n"
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
    puts "   => " " @g.multiple(v, *r) " " => #{@result.inspect} \n"
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
    puts "   => " " @g.andp(v) " " => #{@result.inspect} \n"
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
    puts "   => " " @g.notp(v) " " => #{@result.inspect} \n"
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
    puts "   => " " o " " => #{@result.inspect} \n"
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
    puts "   => " " @g.collect(o) " " => #{@result.inspect} \n"
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
    puts "   => " " @g.dot " " => #{@result.inspect} \n"
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
    puts "   => " " @g.ref(name) " " => #{@result.inspect} \n"
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
    break
    end # end choice

    if _tmp
      puts "   OK value @ #{show_pos}\n"
    else
      puts " FAIL value @ #{show_pos}\n"
    end
    return _tmp
  end
  def _spaces
    puts "START spaces @ #{show_pos}\n"
    _save49 = self.pos

    _save50 = self.pos
    while true # choice
    _tmp = match_string(" ")
    break if _tmp
    self.pos = _save50
    _tmp = match_string("\n")
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
    break
    end # end choice

        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save49
    end
    if _tmp
      puts "   OK spaces @ #{show_pos}\n"
    else
      puts " FAIL spaces @ #{show_pos}\n"
    end
    return _tmp
  end
  def _values
    puts "START values @ #{show_pos}\n"

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
    puts "   => " " @g.seq(s, v) " " => #{@result.inspect} \n"
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
    puts "   => " " @g.seq(l, r) " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save54
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save52
    _tmp = apply('value', :_value)
    break
    end # end choice

    if _tmp
      puts "   OK values @ #{show_pos}\n"
    else
      puts " FAIL values @ #{show_pos}\n"
    end
    return _tmp
  end
  def _choose_cont
    puts "START choose_cont @ #{show_pos}\n"

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
    puts "   => " " v " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save55
    end
    break
    end # end sequence

    if _tmp
      puts "   OK choose_cont @ #{show_pos}\n"
    else
      puts " FAIL choose_cont @ #{show_pos}\n"
    end
    return _tmp
  end
  def _expression
    puts "START expression @ #{show_pos}\n"

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
    puts "   => " " @g.any(v, *alts) " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save57
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save56
    _tmp = apply('values', :_values)
    break
    end # end choice

    if _tmp
      puts "   OK expression @ #{show_pos}\n"
    else
      puts " FAIL expression @ #{show_pos}\n"
    end
    return _tmp
  end
  def _assignment
    puts "START assignment @ #{show_pos}\n"

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
    puts "   => " " @g.set(v, o) " " => #{@result.inspect} \n"
    _tmp = true
    unless _tmp
      self.pos = _save59
    end
    break
    end # end sequence

    if _tmp
      puts "   OK assignment @ #{show_pos}\n"
    else
      puts " FAIL assignment @ #{show_pos}\n"
    end
    return _tmp
  end
  def _assignments
    puts "START assignments @ #{show_pos}\n"

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

    if _tmp
      puts "   OK assignments @ #{show_pos}\n"
    else
      puts " FAIL assignments @ #{show_pos}\n"
    end
    return _tmp
  end
  def _root
    puts "START root @ #{show_pos}\n"

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

    if _tmp
      puts "   OK root @ #{show_pos}\n"
    else
      puts " FAIL root @ #{show_pos}\n"
    end
    return _tmp
  end
end
