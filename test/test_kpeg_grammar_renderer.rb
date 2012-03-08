require 'minitest/autorun'
require 'kpeg'
require 'kpeg/grammar_renderer'
require 'stringio'

class TestKPegGrammarRenderer < MiniTest::Unit::TestCase
  def test_escape
    str = "hello\nbob"
    assert_equal 'hello\nbob', KPeg::GrammarRenderer.escape(str)
    str = "hello\tbob"
    assert_equal 'hello\tbob', KPeg::GrammarRenderer.escape(str)
    str = "\\"
    assert_equal '\\\\', KPeg::GrammarRenderer.escape(str)
    str = 'hello"bob"'
    assert_equal 'hello\\"bob\\"', KPeg::GrammarRenderer.escape(str)
  end

  def test_invoke
    gram = KPeg.grammar do |g|
      g.root = g.invoke("greeting")
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    assert_equal "root = @greeting\n", io.string
  end

  def test_invoke_with_args
    gram = KPeg.grammar do |g|
      g.root = g.invoke("greeting", "(1,2)")
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    assert_equal "root = @greeting(1,2)\n", io.string
  end

  def test_foreign_invoke
    gram = KPeg.grammar do |g|
      g.root = g.foreign_invoke("blah", "greeting")
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    assert_equal "root = %blah.greeting\n", io.string
  end

  def test_foreign_invoke_with_args
    gram = KPeg.grammar do |g|
      g.root = g.foreign_invoke("blah", "greeting", "(1,2)")
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    assert_equal "root = %blah.greeting(1,2)\n", io.string
  end

  def test_dot_render
    gram = KPeg.grammar do |g|
      g.root = g.dot
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    assert_equal "root = .\n", io.string
  end

  def test_tag_render
    gram = KPeg.grammar do |g|
      g.root = g.seq("+", g.t("hello", "greeting"))
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    assert_equal "root = \"+\" \"hello\":greeting\n", io.string
  end

  def test_tag_render_parens
    gram = KPeg.grammar do |g|
      g.root = g.t(g.seq(:b, :c), "greeting")
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    assert_equal "root = (b c):greeting\n", io.string
  end

  def test_grammar_renderer
    gram = KPeg.grammar do |g|
      g.some = g.range('0', '9')
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
some = [0-9]
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
                 [:term, g.t("+"), :term],
                 [:term, g.any("-", "$"), :term],
                 :fact)
      g.fact = g.any(
                 [:fact, g.t("*", "op"), :fact],
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
fact = fact "*":op fact
     | fact "/" fact
     | num
root = term
    GRAM

    assert_equal expected, io.string
  end

  def test_action
    gram = KPeg.grammar do |g|
      g.root = g.seq("hello", g.action("3 + 4"))
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    expected = <<-GRAM
root = "hello" {3 + 4}
    GRAM

    assert_equal expected, io.string
  end

  def test_collect
    gram = KPeg.grammar do |g|
      g.root = g.collect(g.many(g.range("a", "z")))
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    expected = <<-GRAM
root = < [a-z]+ >
    GRAM

    assert_equal expected, io.string
  end

  def test_directives
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.add_directive "header", g.action("\n# coding: UTF-8\n")
      g.add_directive "footer", g.action("\nrequire 'something'\n")
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    expected = <<-TXT
%% footer {
require 'something'
}

%% header {
# coding: UTF-8
}

root = .
    TXT
    assert_equal expected, io.string
  end

  def test_setup_actions
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.add_setup g.action(" attr_reader :foo ")
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    expected = <<-TXT
%% { attr_reader :foo }

root = .
    TXT
    assert_equal expected, io.string
  end

  def test_variables
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.set_variable "name", "Foo"
      g.set_variable "custom_initialize", "true"
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    expected = <<-TXT
%% custom_initialize = true
%% name = Foo

root = .
    TXT
    assert_equal expected, io.string
  end

  def test_multiple_render
    gram = KPeg.grammar do |g|
      g.root = g.multiple("a", 3, 5)
    end

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(gram)
    gr.render(io)

    assert_equal "root = \"a\"[3, 5]\n", io.string
  end
end
