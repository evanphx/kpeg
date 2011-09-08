require 'kpeg/compiled_parser'

class KPeg::StringEscape < KPeg::CompiledParser


  attr_reader :text



  # segment = (< /[\w ]+/ > { text } | "\\" { "\\\\" } | "\n" { "\\n" } | "\t" { "\\t" } | "\b" { "\\b" } | "\"" { "\\\"" } | < . > { text })
  def _segment

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _text_start = self.pos
        _tmp = scan(/\A(?-mix:[\w ]+)/)
        if _tmp
          text = get_text(_text_start)
        end
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  text ; end
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
        _tmp = match_string("\\")
        unless _tmp
          self.pos = _save2
          break
        end
        @result = begin;  "\\\\" ; end
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
        _tmp = match_string("\n")
        unless _tmp
          self.pos = _save3
          break
        end
        @result = begin;  "\\n" ; end
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
        _tmp = match_string("\t")
        unless _tmp
          self.pos = _save4
          break
        end
        @result = begin;  "\\t" ; end
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
        _tmp = match_string("\b")
        unless _tmp
          self.pos = _save5
          break
        end
        @result = begin;  "\\b" ; end
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
        _tmp = match_string("\"")
        unless _tmp
          self.pos = _save6
          break
        end
        @result = begin;  "\\\"" ; end
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
        _text_start = self.pos
        _tmp = get_byte
        if _tmp
          text = get_text(_text_start)
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

      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_segment unless _tmp
    return _tmp
  end

  # root = segment*:s { @text = s.join }
  def _root

    _save = self.pos
    while true # sequence
      _ary = []
      while true
        _tmp = apply(:_segment)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      s = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @text = s.join ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  # embed_seg = ("#" { "\\#" } | segment)
  def _embed_seg

    _save = self.pos
    while true # choice

      _save1 = self.pos
      while true # sequence
        _tmp = match_string("#")
        unless _tmp
          self.pos = _save1
          break
        end
        @result = begin;  "\\#" ; end
        _tmp = true
        unless _tmp
          self.pos = _save1
        end
        break
      end # end sequence

      break if _tmp
      self.pos = _save
      _tmp = apply(:_segment)
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_embed_seg unless _tmp
    return _tmp
  end

  # embed = embed_seg*:s { @text = s.join }
  def _embed

    _save = self.pos
    while true # sequence
      _ary = []
      while true
        _tmp = apply(:_embed_seg)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      s = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  @text = s.join ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_embed unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_segment] = rule_info("segment", "(< /[\\w ]+/ > { text } | \"\\\\\" { \"\\\\\\\\\" } | \"\\n\" { \"\\\\n\" } | \"\\t\" { \"\\\\t\" } | \"\\b\" { \"\\\\b\" } | \"\\\"\" { \"\\\\\\\"\" } | < . > { text })")
  Rules[:_root] = rule_info("root", "segment*:s { @text = s.join }")
  Rules[:_embed_seg] = rule_info("embed_seg", "(\"\#\" { \"\\\\\#\" } | segment)")
  Rules[:_embed] = rule_info("embed", "embed_seg*:s { @text = s.join }")
end
