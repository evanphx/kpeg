require 'kpeg/compiled_parser'

class Matcher < KPeg::CompiledParser

  # upper = [A-Z]
  def _upper
    _save = self.pos
    _tmp = get_byte
    if _tmp
      unless _tmp >= 65 and _tmp <= 90
        self.pos = _save
        _tmp = nil
      end
    end
    set_failed_rule :_upper unless _tmp
    return _tmp
  end

  # lower = [a-z]
  def _lower
    _save = self.pos
    _tmp = get_byte
    if _tmp
      unless _tmp >= 97 and _tmp <= 122
        self.pos = _save
        _tmp = nil
      end
    end
    set_failed_rule :_lower unless _tmp
    return _tmp
  end

  # word = "a"+
  def _word
    _save = self.pos
    _tmp = match_string("a")
    if _tmp
      while true
        _tmp = match_string("a")
        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save
    end
    set_failed_rule :_word unless _tmp
    return _tmp
  end

  # root = word
  def _root
    _tmp = apply(:_word)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_upper] = rule_info("upper", "[A-Z]")
  Rules[:_lower] = rule_info("lower", "[a-z]")
  Rules[:_word] = rule_info("word", "\"a\"+")
  Rules[:_root] = rule_info("root", "word")
end
