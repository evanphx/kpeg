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
class Test
  def root(x)
    _tmp = x.get_byte
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_str
    gram = KPeg.grammar do |g|
      g.root = g.str("hello")
    end

    str = <<-STR
class Test
  def root(x)
    _tmp = x.scan(/hello/)
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_reg
    gram = KPeg.grammar do |g|
      g.root = g.reg(/[0-9]/)
    end

    str = <<-STR
class Test
  def root(x)
    _tmp = x.scan(/(?-mix:[0-9])/)
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_char_range
    gram = KPeg.grammar do |g|
      g.root = g.range("a", "z")
    end

    str = <<-STR
class Test
  def root(x)
    _tmp = x.get_byte
    fix = _tmp[0]
    _tmp = nil unless fix >= 97 and fix <= 122
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_char_range_in_seq
    gram = KPeg.grammar do |g|
      g.root = g.seq(g.range("a", "z"), "hello")
    end

    str = <<-STR
class Test
  def root(x)

    while true # sequence
    _tmp = x.get_byte
    fix = _tmp[0]
    _tmp = nil unless fix >= 97 and fix <= 122
    break unless _tmp
    _tmp = x.scan(/hello/)
    break
    end # end sequence

    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_any
    gram = KPeg.grammar do |g|
      g.root = g.any("hello", "world")
    end

    str = <<-STR
class Test
  def root(x)

    while true # choice
    _tmp = x.scan(/hello/)
    break if _tmp
    _tmp = x.scan(/world/)
    break
    end # end choice

    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_maybe
    gram = KPeg.grammar do |g|
      g.root = g.maybe("hello")
    end

    str = <<-STR
class Test
  def root(x)
    _tmp = x.scan(/hello/)
    _tmp = true unless _tmp
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_kleene
    gram = KPeg.grammar do |g|
      g.root = g.kleene("hello")
    end

    str = <<-STR
class Test
  def root(x)
    ary = []
    while true
      _tmp = x.scan(/hello/)
      if _tmp
        ary << _tmp
      else
        break
      end
    end
    _tmp = ary
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_many
    gram = KPeg.grammar do |g|
      g.root = g.many("hello")
    end

    str = <<-STR
class Test
  def root(x)
    _tmp = x.scan(/hello/)
    if _tmp
      ary = [_tmp]
      while true
        _tmp = x.scan(/hello/)
        if _tmp
          ary << _tmp
        else
          break
        end
      end
      _tmp = ary
    end
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_multiple
    gram = KPeg.grammar do |g|
      g.root = g.multiple("hello", 5, 9)
    end

    str = <<-STR
class Test
  def root(x)
    ary = []
    while true
      _tmp = x.scan(/hello/)
      if _tmp
        ary << _tmp
      else
        break
      end
    end
    if ary.size >= 5 and ary.size <= 9
      _tmp = ary
    else
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
class Test
  def root(x)

    while true # sequence
    _tmp = x.scan(/hello/)
    break unless _tmp
    _tmp = x.scan(/world/)
    break
    end # end sequence

    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_andp
    gram = KPeg.grammar do |g|
      g.root = g.andp("hello")
    end

    str = <<-STR
class Test
  def root(x)
    save = x.pos
    _tmp = x.scan(/hello/)
    x.pos = save
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_notp
    gram = KPeg.grammar do |g|
      g.root = g.notp("hello")
    end

    str = <<-STR
class Test
  def root(x)
    save = x.pos
    _tmp = x.scan(/hello/)
    x.pos = save
    _tmp = !_tmp
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_ref
    gram = KPeg.grammar do |g|
      g.root = g.ref("greeting")
    end

    str = <<-STR
class Test
  def root(x)
    _tmp = x.find_memo('greeting')
    unless _tmp
      _tmp = _greeting(x)
      x.set_memo('greeting', _tmp)
    end
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_tag
    gram = KPeg.grammar do |g|
      g.root = g.t g.str("hello"), "t"
    end

    str = <<-STR
class Test
  def root(x)
    _tmp = x.scan(/hello/)
    t = _tmp
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
class Test
  def root(x)
    _tmp = x.scan(/hello/)
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_action
    gram = KPeg.grammar do |g|
      g.root = g.action "puts 'hello'"
    end

    str = <<-STR
class Test
  def root(x)
    _tmp = begin; puts 'hello'; end
    return _tmp
  end
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

end
