require 'test/unit'
require 'kpeg'
require 'stringio'

class TestKPeg < Test::Unit::TestCase
  def assert_match(m, str)
    assert_kind_of KPeg::Match, m
    assert_equal str, m.string
  end

  def test_str
    gram = KPeg.grammar do |g|
      g.root = g.str("hello")
    end

    assert_match KPeg.match("hello", gram), "hello"
    assert_equal nil, KPeg.match("vador", gram)
  end

  def test_reg
    gram = KPeg.grammar do |g|
      g.root = g.reg(/[0-9]/)
    end

    assert_match KPeg.match("3", gram), "3"
  end

  def test_any
    gram = KPeg.grammar do |g|
      g.root = g.any g.str("hello"), g.str("chicken")
    end

    assert_match KPeg.match("hello", gram), "hello"
    assert_match KPeg.match("chicken", gram), "chicken"
    assert_equal nil, KPeg.match("vador", gram)
  end

  def test_maybe
    gram = KPeg.grammar do |g|
      g.root = g.maybe g.str("hello")
    end

    m = KPeg.match "hello", gram
    assert_kind_of KPeg::Match, m
    assert_equal 1, m.matches.size
    assert_match m.matches[0], "hello"

    m = KPeg.match "surprise", gram
    assert_kind_of KPeg::Match, m
    assert_equal 0, m.matches.size
  end

  def test_many
    gram = KPeg.grammar do |g|
      g.root = g.many g.str("run")
    end

    m = KPeg.match "runrunrun", gram
    assert_kind_of KPeg::Match, m
    assert_equal 3, m.matches.size
    m.matches.each do |sm|
      assert_match sm, "run"
    end

    assert_equal nil, KPeg.match("vador", gram)
  end

  def test_kleene
    gram = KPeg.grammar do |g|
      g.root = g.kleene g.str("run")
    end

    m = KPeg.match "runrunrun", gram
    assert_kind_of KPeg::Match, m
    assert_equal 3, m.matches.size
    m.matches.each do |sm|
      assert_match sm, "run"
    end

    m = KPeg.match "chicken", gram
    assert_kind_of KPeg::Match, m
    assert_equal 0, m.matches.size
  end

  def test_multiple
    gram = KPeg.grammar do |g|
      g.root = g.multiple g.str("run"), 2, 4
    end

    m = KPeg.match "runrun", gram
    assert_kind_of KPeg::Match, m
    assert_equal 2, m.matches.size
    m.matches.each do |sm|
      assert_match sm, "run"
    end

    m = KPeg.match "runrunrun", gram
    assert_kind_of KPeg::Match, m
    assert_equal 3, m.matches.size
    m.matches.each do |sm|
      assert_match sm, "run"
    end

    m = KPeg.match "runrunrunrun", gram
    assert_kind_of KPeg::Match, m
    assert_equal 4, m.matches.size
    m.matches.each do |sm|
      assert_match sm, "run"
    end

    assert_equal nil, KPeg.match("run", gram) 
    assert_equal nil, KPeg.match("runrunrunrunrun", gram) 
    assert_equal nil, KPeg.match("vador", gram) 
  end

  def test_seq
    gram = KPeg.grammar do |g|
      g.root = g.seq g.str("hello"), g.str(", world")
    end

    m = KPeg.match "hello, world", gram
    assert_kind_of KPeg::Match, m
    assert_match m.matches[0], "hello"
    assert_match m.matches[1], ", world"

    assert_equal nil, KPeg.match("vador", gram)
    assert_equal nil, KPeg.match("hello, vador", gram)
  end

  def test_andp
    gram = KPeg.grammar do |g|
      g.root = g.seq g.andp(g.str("h")), g.str("hello")
    end

    m = KPeg.match "hello", gram
    assert_equal m.matches.size, 2
    assert_match m.matches[0], ""
    assert_match m.matches[1], "hello"
  end

  def test_notp
    gram = KPeg.grammar do |g|
      g.root = g.seq g.notp(g.str("g")), g.str("hello")
    end

    m = KPeg.match "hello", gram
    assert_equal m.matches.size, 2
    assert_match m.matches[0], ""
    assert_match m.matches[1], "hello"
  end

  def test_ref
    gram = KPeg.grammar do |g|
      g.greeting = g.str("hello")
      g.root = g.ref "greeting"
    end

    m = KPeg.match "hello", gram
    assert_match m, "hello"
  end

  def test_naming
    gram = KPeg.grammar do |g|
      g.greeting = g.str("hello")
      g.root = g.greeting
    end

    m = KPeg.match "hello", gram
    assert_match m, "hello"
  end


  def test_memoization
    gram = KPeg.grammar do |g|
      g.one = g.str("1")
      g.two = g.str("2")

      g.root = g.any(
        [:one, "-", :two],
        [:one, "+", :two]
        )
    end

    parser = KPeg::Parser.new "1+2", gram
    m = parser.apply(gram.root)

    assert_equal 3, m.matches.size
    assert_match m.matches[0], "1"
    assert_match m.matches[1], "+"
    assert_match m.matches[2], "2"

    one = gram.find("one")
    two = gram.find("two")

    # We try 1 twice
    assert_equal 2, parser.memoizations[one][0].uses

    # but we only get as far as 2 once
    assert_equal 1, parser.memoizations[two][2].uses
  end

  def test_left_recursion
    gram = KPeg.grammar do |g|
      g.num  = g.reg(/[0-9]/)
      g.expr = g.any [:expr, "-", :num], :num

      g.root = g.expr
    end

    parser = KPeg::Parser.new "1-2-3", gram

    m = parser.apply(gram.root)
    assert_equal 3, m.matches.size

    left = m.matches[0]
    assert_equal 3, left.matches.size
    assert_match left.matches[0], "1"
    assert_match left.matches[1], "-"
    assert_match left.matches[2], "2"
    assert_match m.matches[1], "-"
    assert_match m.matches[2], "3"

    parser = KPeg::Parser.new "hello", gram
    m = parser.apply(gram.root)

    assert_equal nil, m
  end

  def test_math_grammar
    gram = KPeg.grammar do |g|
      g.num = g.reg(/[0-9]/)
      g.term = g.seq(:term, "+", :term) \
             | g.seq(:term, "-", :term) \
             | :fact

      g.fact = g.seq(:fact, "*", :fact) \
             | g.seq(:fact, "/", :fact) \
             | :num

      g.root = g.term
    end

    sub = KPeg.match "4*3-8/9", gram
    mul = sub.matches[0]
    div = sub.matches[2]

    assert_match mul.matches[0], "4"
    assert_match mul.matches[1], "*"
    assert_match mul.matches[2], "3"

    assert_match sub.matches[1], "-"

    assert_match div.matches[0], "8"
    assert_match div.matches[1], "/"
    assert_match div.matches[2], "9"
  end

  def test_grammar_renderer
    gram = KPeg.grammar do |g|
      g.num = g.reg(/[0-9]/)
      g.term = g.any(
                 [:term, "+", :term],
                 [:term, "-", :term],
                 :fact)
      g.fact = g.any(
                 [:fact, "*", :fact],
                 [:fact, "/", :fact],
                 :num
               )
      g.root = g.term
    end

    m = KPeg.match "4*3-8/9", gram

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    expected = <<-GRAM
 num = /[0-9]/
term = term "+" term 
     | term "-" term 
     | fact
fact = fact "*" fact 
     | fact "/" fact 
     | num
root = term
    GRAM

    assert_equal expected, io.string
  end

  def test_grammar_renderer2
    gram = KPeg.grammar do |g|
      g.num = g.reg(/[0-9]/)
      g.term = g.any(
                 [:term, "+", :term],
                 [:term, g.any("-", "$"), :term],
                 :fact)
      g.fact = g.any(
                 [:fact, "*", :fact],
                 [:fact, "/", :fact],
                 :num
               )
      g.root = g.term
    end

    m = KPeg.match "4*3-8/9", gram

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    expected = <<-GRAM
 num = /[0-9]/
term = term "+" term 
     | term ("-" | "$") term 
     | fact
fact = fact "*" fact 
     | fact "/" fact 
     | num
root = term
    GRAM

    assert_equal expected, io.string
  end
end
