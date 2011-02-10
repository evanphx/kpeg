require 'test/unit'
require 'kpeg'
require 'kpeg/code_generator'
require 'stringio'

class TestKPegCodeGenerator < Test::Unit::TestCase
  def test_dot
    gram = KPeg.grammar do |g|
      g.root = g.dot
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _tmp = get_byte
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert_equal ?h, cg.run("hello")
  end

  def test_str
    gram = KPeg.grammar do |g|
      g.root = g.str("hello")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _tmp = match_string("hello")
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert_equal "hello", cg.run("hello")
  end

  def test_reg
    gram = KPeg.grammar do |g|
      g.root = g.reg(/[0-9]/)
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _tmp = scan(/(?-mix:[0-9])/)
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert_equal true, cg.run("9")
    assert_equal true, cg.run("1")
    assert_equal nil, cg.run("a")
  end

  def test_char_range
    gram = KPeg.grammar do |g|
      g.root = g.range("a", "z")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _tmp = get_byte
    if _tmp
      unless _tmp >= 97 and _tmp <= 122
        unget_one
        _tmp = nil
      end
    end
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert_equal ?z, cg.run("z")
    assert_equal ?a, cg.run("a")
    assert_equal nil, cg.run("0")
  end

  def test_char_range_in_seq
    gram = KPeg.grammar do |g|
      g.root = g.seq(g.range("a", "z"), "hello")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root

    _save = self.pos
    while true # sequence
    _tmp = get_byte
    if _tmp
      unless _tmp >= 97 and _tmp <= 122
        unget_one
        _tmp = nil
      end
    end
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("hello")
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert_equal "hello", cg.run("ahello")
    assert_equal "hello", cg.run("zhello")
    assert_equal nil, cg.run("0hello")
    assert_equal nil, cg.run("ajello")
  end

  def test_any
    gram = KPeg.grammar do |g|
      g.root = g.any("hello", "world")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root

    _save = self.pos
    while true # choice
    _tmp = match_string("hello")
    break if _tmp
    self.pos = _save
    _tmp = match_string("world")
    break
    end # end choice

    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert_equal "hello", cg.run("hello")
    assert_equal "world", cg.run("world")
    assert_equal nil, cg.run("jello")
  end

  def test_any_resets_pos
    gram = KPeg.grammar do |g|
      g.root = g.any(g.seq("hello", "world"), "hello balloons")
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    code = cg.make("helloworld")
    assert_equal "world", code.run
    assert_equal 10, code.pos

    assert_equal "hello balloons", cg.run("hello balloons")
  end

  def test_maybe
    gram = KPeg.grammar do |g|
      g.root = g.maybe("hello")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _save = self.pos
    _tmp = match_string("hello")
    unless _tmp
      _tmp = true
      self.pos = _save
    end
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert_equal "hello", cg.run("hello")
    assert_equal true, cg.run("jello")
  end

  def test_maybe_resets_pos
    gram = KPeg.grammar do |g|
      g.root = g.maybe(g.seq("hello", "world"))
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal "world", cg.run("helloworld")

    code = cg.make("hellojello")
    assert_equal true, code.run
    assert_equal 0, code.pos
  end

  def test_kleene
    gram = KPeg.grammar do |g|
      g.root = g.kleene("hello")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    while true
    _tmp = match_string("hello")
    break unless _tmp
    end
    _tmp = true
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hellohellohello")
    assert_equal true, code.run
    assert_equal 15, code.pos
  end

  def test_kleene_reset_pos
    gram = KPeg.grammar do |g|
      g.root = g.kleene(g.seq("hello", "world"))
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    code = cg.make("helloworldhelloworld")
    assert_equal true, code.run
    assert_equal 20, code.pos

    code = cg.make("hellojello")
    assert_equal true, code.run
    assert_equal 0, code.pos
  end

  def test_many
    gram = KPeg.grammar do |g|
      g.root = g.many("hello")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _save = self.pos
    _tmp = match_string("hello")
    if _tmp
      while true
        _tmp = match_string("hello")
        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save
    end
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hellohello")
    assert_equal true, code.run
    assert_equal 10, code.pos

    code = cg.make("hello")
    assert_equal true, code.run
    assert_equal 5, code.pos

    code = cg.make("")
    assert_equal nil, code.run
  end

  def test_many_resets_pos
    gram = KPeg.grammar do |g|
      g.root = g.many(g.seq("hello", "world"))
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    code = cg.make("helloworldhelloworld")
    assert_equal true, code.run
    assert_equal 20, code.pos

    code = cg.make("hellojello")
    assert_equal nil, code.run
    assert_equal 0, code.pos
  end

  def test_multiple
    gram = KPeg.grammar do |g|
      g.root = g.multiple("hello", 5, 9)
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _save = self.pos
    _count = 0
    while true
      _tmp = match_string("hello")
      if _tmp
        _count += 1
        break if _count == 9
      else
        break
      end
    end
    if _count >= 5
      _tmp = true
    else
      self.pos = _save
      _tmp = nil
    end
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_seq
    gram = KPeg.grammar do |g|
      g.root = g.seq("hello", "world")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root

    _save = self.pos
    while true # sequence
    _tmp = match_string("hello")
    unless _tmp
      self.pos = _save
      break
    end
    _tmp = match_string("world")
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_seq_resets_pos
    gram = KPeg.grammar do |g|
      g.root = g.seq("hello", "world")
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    code = cg.make("helloworld")
    assert_equal "world", code.run

    code = cg.make("hellojello")
    assert_equal nil, code.run
    assert_equal 0, code.pos
  end

  def test_andp
    gram = KPeg.grammar do |g|
      g.root = g.andp("hello")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _save = self.pos
    _tmp = match_string("hello")
    self.pos = _save
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert_equal "hello", code.run
    assert_equal 0, code.pos

    code = cg.make("jello")
    assert_equal nil, code.run
    assert_equal 0, code.pos
  end

  def test_notp
    gram = KPeg.grammar do |g|
      g.root = g.notp("hello")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _save = self.pos
    _tmp = match_string("hello")
    self.pos = _save
    _tmp = _tmp ? nil : true
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert_equal nil, code.run
    assert_equal 0, code.pos

    code = cg.make("jello")
    assert_equal true, code.run
    assert_equal 0, code.pos
  end

  def test_ref
    gram = KPeg.grammar do |g|
      g.greeting = "hello"
      g.root = g.ref("greeting")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _greeting
    _tmp = match_string("hello")
    return _tmp
  end
  def _root
    _tmp = apply('greeting', :_greeting)
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert_equal "hello", cg.run("hello")
  end

  def test_tag
    gram = KPeg.grammar do |g|
      g.root = g.t g.str("hello"), "t"
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _tmp = match_string("hello")
    t = @result
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_noname_tag
    gram = KPeg.grammar do |g|
      g.root = g.t g.str("hello")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _tmp = match_string("hello")
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_tag_maybe
    gram = KPeg.grammar do |g|
      g.hello = g.seq(g.collect("hello"), g.action("text"))
      g.root = g.seq g.t(g.maybe(:hello), "lots"), g.action("lots")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _hello

    _save = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = match_string("hello")
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save
      break
    end
    @result = begin; text; end
    _tmp = true
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    return _tmp
  end
  def _root

    _save1 = self.pos
    while true # sequence
    _save2 = self.pos
    _tmp = apply('hello', :_hello)
    @value = nil unless _tmp
    unless _tmp
      _tmp = true
      self.pos = _save2
    end
    lots = @result
    unless _tmp
      self.pos = _save1
      break
    end
    @result = begin; lots; end
    _tmp = true
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert_equal true, code.run
    assert_equal "hello", code.result

    code = cg.make("")
    assert_equal true, code.run
    assert_equal nil, code.result
  end


  def test_tag_multiple
    gram = KPeg.grammar do |g|
      g.hello = g.seq(g.collect("hello"), g.action("text"))
      g.root = g.seq g.t(g.kleene(:hello), "lots"), g.action("lots")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _hello

    _save = self.pos
    while true # sequence
    _text_start = self.pos
    _tmp = match_string("hello")
    if _tmp
      set_text(_text_start)
    end
    unless _tmp
      self.pos = _save
      break
    end
    @result = begin; text; end
    _tmp = true
    unless _tmp
      self.pos = _save
    end
    break
    end # end sequence

    return _tmp
  end
  def _root

    _save1 = self.pos
    while true # sequence
    _ary = []
    while true
    _tmp = apply('hello', :_hello)
    _ary << @result if _tmp
    break unless _tmp
    end
    _tmp = true
    @result = _ary
    lots = @result
    unless _tmp
      self.pos = _save1
      break
    end
    @result = begin; lots; end
    _tmp = true
    unless _tmp
      self.pos = _save1
    end
    break
    end # end sequence

    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hellohello")
    assert_equal true, code.run
    assert_equal ["hello", "hello"], code.result

    code = cg.make("hello")
    assert_equal true, code.run
    assert_equal ["hello"], code.result

    code = cg.make("")
    assert_equal true, code.run
    assert_equal [], code.result
  end

  def test_action
    gram = KPeg.grammar do |g|
      g.root = g.action "3 + 4"
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    @result = begin; 3 + 4; end
    _tmp = true
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("")
    assert_equal true, code.run
    assert_equal 7, code.result
  end

  def test_collect
    gram = KPeg.grammar do |g|
      g.root = g.collect("hello")
    end

    str = <<-STR
class Test < KPeg::CompiledGrammar
  def _root
    _text_start = self.pos
    _tmp = match_string("hello")
    if _tmp
      set_text(_text_start)
    end
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert_equal "hello", code.run
    assert_equal "hello", code.text
  end

end
