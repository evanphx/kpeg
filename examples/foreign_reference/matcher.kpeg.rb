require 'kpeg/compiled_parser'

class Matcher < KPeg::CompiledParser


	require "literals.kpeg.rb"


  def setup_foreign_grammar
    @_grammar_grammer1 = Literal.new(nil)
  end

  # root = (%grammer1.alpha %grammer1.space*)+ %grammer1.period
  def _root

    _save = self.pos
    while true # sequence
    _save1 = self.pos

    _save2 = self.pos
    while true # sequence
    _tmp = @_grammar_grammer1.external_invoke(self, :_alpha)
    unless _tmp
      self.pos = _save2
      break
    end
    while true
    _tmp = @_grammar_grammer1.external_invoke(self, :_space)
    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save2
    end
    break
    end # end sequence

    if _tmp
      while true
    
    _save4 = self.pos
    while true # sequence
    _tmp = @_grammar_grammer1.external_invoke(self, :_alpha)
    unless _tmp
      self.pos = _save4
      break
    end
    while true
    _tmp = @_grammar_grammer1.external_invoke(self, :_space)
    break unless _tmp
    end
    _tmp = true
    unless _tmp
      self.pos = _save4
    end
    break
    end # end sequence

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
    _tmp = @_grammar_grammer1.external_invoke(self, :_period)
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "(%grammer1.alpha %grammer1.space*)+ %grammer1.period")
end
