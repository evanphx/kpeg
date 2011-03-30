require 'kpeg/compiled_parser'

class Upper < KPeg::CompiledParser


  attr_accessor :output



  # period = "."
  def _period
    _tmp = match_string(".")
    set_failed_rule :_period unless _tmp
    return _tmp
  end

  # space = " "
  def _space
    _tmp = match_string(" ")
    set_failed_rule :_space unless _tmp
    return _tmp
  end

  # alpha = < /[A-Za-z]/ > { text.upcase }
  def _alpha

    _save = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = scan(/\A(?-mix:[A-Za-z])/)
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save
      break
    end
    @result = begin;  text.upcase ; end
    _tmp = true
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_alpha unless _tmp
    return _tmp
  end

  # word = (< alpha:a word:w > { "#{a}#{w}" } | < alpha:a space+ > { "#{a} "} | < alpha:a > { a })
  def _word

    _save = self.pos
    while true # choice

    _save1 = self.pos
    while true # sequence
    _text_start = self.pos

    _save2 = self.pos
    while true # sequence
    _tmp = apply(:_alpha)
    a = @result
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_word)
    w = @result
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
    @result = begin;  "#{a}#{w}" ; end
    _tmp = true
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save

    _save3 = self.pos
    while true # sequence
    _text_start = self.pos

    _save4 = self.pos
    while true # sequence
    _tmp = apply(:_alpha)
    a = @result
    unless _tmp
      self.pos = _save4
      break
    end
    _save5 = self.pos
    _tmp = apply(:_space)
    if _tmp
      while true
        _tmp = apply(:_space)
        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save5
    end
    unless _tmp
      self.pos = _save4
    end
    break
    end # end sequence

    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save3
      break
    end
    @result = begin;  "#{a} "; end
    _tmp = true
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save

    _save6 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = apply(:_alpha)
    a = @result
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save6
      break
    end
    @result = begin;  a ; end
    _tmp = true
    unless _tmp
      self.pos = _save6
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_word unless _tmp
    return _tmp
  end

  # sentence = (< word:w sentence:s > { "#{w}#{s}" } | < word:w > { w })
  def _sentence

    _save = self.pos
    while true # choice

    _save1 = self.pos
    while true # sequence
    _text_start = self.pos

    _save2 = self.pos
    while true # sequence
    _tmp = apply(:_word)
    w = @result
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_sentence)
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
    @result = begin;  "#{w}#{s}" ; end
    _tmp = true
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save

    _save3 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = apply(:_word)
    w = @result
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save3
      break
    end
    @result = begin;  w ; end
    _tmp = true
    unless _tmp
      self.pos = _save3
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_sentence unless _tmp
    return _tmp
  end

  # document = (< sentence:s period space* document:d > { "#{s}. #{d}" } | < sentence:s period > { "#{s}." } | < sentence:s > { s })
  def _document

    _save = self.pos
    while true # choice

    _save1 = self.pos
    while true # sequence
    _text_start = self.pos

    _save2 = self.pos
    while true # sequence
    _tmp = apply(:_sentence)
    s = @result
    unless _tmp
      self.pos = _save2
      break
    end
    _tmp = apply(:_period)
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
    _tmp = apply(:_document)
    d = @result
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
    @result = begin;  "#{s}. #{d}" ; end
    _tmp = true
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save

    _save4 = self.pos
    while true # sequence
    _text_start = self.pos

    _save5 = self.pos
    while true # sequence
    _tmp = apply(:_sentence)
    s = @result
    unless _tmp
      self.pos = _save5
      break
    end
    _tmp = apply(:_period)
    unless _tmp
      self.pos = _save5
    end
    break
    end # end sequence

    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save4
      break
    end
    @result = begin;  "#{s}." ; end
    _tmp = true
    unless _tmp
      self.pos = _save4
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save

    _save6 = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = apply(:_sentence)
    s = @result
    if _tmp
      text = get_text(_text_start)
    end
    unless _tmp
      self.pos = _save6
      break
    end
    @result = begin;  s ; end
    _tmp = true
    unless _tmp
      self.pos = _save6
    end
    break
    end # end sequence

    break if _tmp
    self.pos = _save
    break
    end # end choice

    set_failed_rule :_document unless _tmp
    return _tmp
  end

  # root = document:d { @output = d }
  def _root

    _save = self.pos
    while true # sequence
    _tmp = apply(:_document)
    d = @result
    unless _tmp
      self.pos = _save
      break
    end
    @result = begin;  @output = d ; end
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
  Rules[:_period] = rule_info("period", "\".\"")
  Rules[:_space] = rule_info("space", "\" \"")
  Rules[:_alpha] = rule_info("alpha", "< /[A-Za-z]/ > { text.upcase }")
  Rules[:_word] = rule_info("word", "(< alpha:a word:w > { \"\#{a}\#{w}\" } | < alpha:a space+ > { \"\#{a} \"} | < alpha:a > { a })")
  Rules[:_sentence] = rule_info("sentence", "(< word:w sentence:s > { \"\#{w}\#{s}\" } | < word:w > { w })")
  Rules[:_document] = rule_info("document", "(< sentence:s period space* document:d > { \"\#{s}. \#{d}\" } | < sentence:s period > { \"\#{s}.\" } | < sentence:s > { s })")
  Rules[:_root] = rule_info("root", "document:d { @output = d }")
end
