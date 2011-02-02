require 'test/unit'
require 'kpeg'

class TestKPeg < Test::Unit::TestCase
  def assert_match(m, str)
    assert_kind_of KPeg::Match, m
    assert_equal str, m.string
  end

  def test_str
    node = KPeg.layout do |l|
      l.str("hello")
    end

    assert_match KPeg.match("hello", node), "hello"
    assert_equal nil, KPeg.match("vador", node)
  end

  def test_reg
    node = KPeg.layout do |l|
      l.reg(/[0-9]/)
    end

    assert_match KPeg.match("3", node), "3"
  end

  def test_any
    node = KPeg.layout do |l|
      l.any l.str("hello"), l.str("chicken")
    end

    assert_match KPeg.match("hello", node), "hello"
    assert_match KPeg.match("chicken", node), "chicken"
    assert_equal nil, KPeg.match("vador", node)
  end

  def test_maybe
    node = KPeg.layout do |l|
      l.maybe l.str("hello")
    end

    m = KPeg.match "hello", node
    assert_kind_of KPeg::Match, m
    assert_equal 1, m.matches.size
    assert_match m.matches[0], "hello"

    m = KPeg.match "surprise", node
    assert_kind_of KPeg::Match, m
    assert_equal 0, m.matches.size
  end

  def test_many
    node = KPeg.layout do |l|
      l.many l.str("run")
    end

    m = KPeg.match "runrunrun", node
    assert_kind_of KPeg::Match, m
    assert_equal 3, m.matches.size
    m.matches.each do |sm|
      assert_match sm, "run"
    end

    assert_equal nil, KPeg.match("vador", node)
  end

  def test_kleene
    node = KPeg.layout do |l|
      l.kleene l.str("run")
    end

    m = KPeg.match "runrunrun", node
    assert_kind_of KPeg::Match, m
    assert_equal 3, m.matches.size
    m.matches.each do |sm|
      assert_match sm, "run"
    end

    m = KPeg.match "chicken", node
    assert_kind_of KPeg::Match, m
    assert_equal 0, m.matches.size
  end

  def test_multiple
    node = KPeg.layout do |l|
      l.multiple l.str("run"), 2, 4
    end

    m = KPeg.match "runrun", node
    assert_kind_of KPeg::Match, m
    assert_equal 2, m.matches.size
    m.matches.each do |sm|
      assert_match sm, "run"
    end

    m = KPeg.match "runrunrun", node
    assert_kind_of KPeg::Match, m
    assert_equal 3, m.matches.size
    m.matches.each do |sm|
      assert_match sm, "run"
    end

    m = KPeg.match "runrunrunrun", node
    assert_kind_of KPeg::Match, m
    assert_equal 4, m.matches.size
    m.matches.each do |sm|
      assert_match sm, "run"
    end

    assert_equal nil, KPeg.match("run", node) 
    assert_equal nil, KPeg.match("runrunrunrunrun", node) 
    assert_equal nil, KPeg.match("vador", node) 
  end

  def test_seq
    node = KPeg.layout do |l|
      l.seq l.str("hello"), l.str(", world")
    end

    m = KPeg.match "hello, world", node
    assert_kind_of KPeg::Match, m
    assert_match m.matches[0], "hello"
    assert_match m.matches[1], ", world"

    assert_equal nil, KPeg.match("vador", node)
    assert_equal nil, KPeg.match("hello, vador", node)
  end

  def test_andp
    node = KPeg.layout do |l|
      l.seq l.andp(l.str("h")), l.str("hello")
    end

    m = KPeg.match "hello", node
    assert_equal m.matches.size, 2
    assert_match m.matches[0], ""
    assert_match m.matches[1], "hello"
  end

  def test_andp
    node = KPeg.layout do |l|
      l.seq l.notp(l.str("g")), l.str("hello")
    end

    m = KPeg.match "hello", node
    assert_equal m.matches.size, 2
    assert_match m.matches[0], ""
    assert_match m.matches[1], "hello"
  end

  def test_ref
    node = KPeg.layout do |l|
      l.greeting = l.str("hello")
      l.ref "greeting"
    end

    m = KPeg.match "hello", node
    assert_match m, "hello"
  end

  def test_naming
    node = KPeg.layout do |l|
      l.greeting = l.str("hello")
      l.greeting
    end

    m = KPeg.match "hello", node
    assert_match m, "hello"
  end


  def test_memoization
    one = nil
    two = nil

    node = KPeg.layout do |l|
      one = l.str("1")
      two = l.str("2")

      l.any(
        l.seq(one, l.str("-"), two),
        l.seq(one, l.str("+"), two)
      )
    end

    parser = KPeg::Parser.new "1+2"
    m = parser.apply(node)

    assert_equal 3, m.matches.size
    assert_match m.matches[0], "1"
    assert_match m.matches[1], "+"
    assert_match m.matches[2], "2"

    # We try 1 twice
    assert_equal 2, parser.memoizations[one][0].uses

    # but we only get as far as 2 once
    assert_equal 1, parser.memoizations[two][2].uses
  end

  def test_left_recursion
    node = KPeg.layout do |l|
      l.num  = l.reg(/[0-9]/)
      l.expr = l.any(
                      l.seq(l.ref("expr"), "-", l.ref("num")),
                      l.ref("num"))
    end

    parser = KPeg::Parser.new "1"

    m = parser.apply(node)
    assert_equal 2, m.matches.size
  end
end
