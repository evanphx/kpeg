require 'kpeg/compiled_parser'

class Literal < KPeg::CompiledParser

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

  # alpha = /[A-Za-z]/
  def _alpha
    _tmp = scan(/\A(?-mix:[A-Za-z])/)
    set_failed_rule :_alpha unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_period] = rule_info("period", "\".\"")
  Rules[:_space] = rule_info("space", "\" \"")
  Rules[:_alpha] = rule_info("alpha", "/[A-Za-z]/")
end
