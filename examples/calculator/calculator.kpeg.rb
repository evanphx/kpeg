require 'kpeg/compiled_parser'

class Calculator < KPeg::CompiledParser


  attr_accessor :result



  # space = " "
  def _space
    _tmp = match_string(" ")
    set_failed_rule :_space unless _tmp
    return _tmp
  end

  # num = < /[1-9][0-9]*/ > { text.to_i }
  def _num

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
    @result = begin;  text.to_i ; end
    _tmp = true
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_num unless _tmp
    return _tmp
  end

  # sum = (< num:n space* "+" space* sum:s > { n + s } | < num:n > { n })
  def _sum

    _save = self.pos
    while true # choice

    _save1 = self.pos
    while true # sequence
    _text_start = self.pos

    _save2 = self.pos
    while true # sequence
    _tmp = apply(:_num)
    n = @result
    unless _tmp
      self.pos = _save2
      break
    end
    while true
    _tmp = apply(:_space)
    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = match_string("+")
    unless _tmp
      self.pos = _save2
      break
    end
    while true
    _tmp = apply(:_space)
    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_sum)
    s = @result
    unless _tmp
      self.pos = _save2
    end
    break
    end # end sequence

    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save1
      break
    end
    @result = begin;  n + s ; end
    _tmp = true
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save

    _save5 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = apply(:_num)
    n = @result
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save5
      break
    end
    @result = begin;  n ; end
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

    set_failed_rule :_sum unless _tmp
    return _tmp
  end

  # root = sum:s { @result = s }
  def _root

    _save = self.pos
    while true # sequence
    _tmp = apply(:_sum)
    s = @result
    unless _tmp
      self.pos = _save
      break
    end
    @result = begin;  @result = s ; end
    _tmp = true
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_space] = rule_info("space", "\" \"")
  Rules[:_num] = rule_info("num", "< /[1-9][0-9]*/ > { text.to_i }")
  Rules[:_sum] = rule_info("sum", "(< num:n space* \"+\" space* sum:s > { n + s } | < num:n > { n })")
  Rules[:_root] = rule_info("root", "sum:s { @result = s }")
end
