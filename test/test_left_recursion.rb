require 'test/unit'
require 'kpeg'
require 'kpeg/format_parser'
require 'kpeg/code_generator'
require 'stringio'

class TestKPegLeftRecursion < Test::Unit::TestCase
  GRAMMAR = <<-'STR'

  name = name:n "[]" { [:array, n] }
       | < /\w+/ > { [:word, text] }

  root = name

  STR

  def test_invoke_rule_directly
    parc = KPeg::FormatParser.new(GRAMMAR)
    assert parc.parse, "Unable to parse"

    gram = parc.grammar

    # gr = KPeg::GrammarRenderer.new(gram)
    # puts
    # gr.render(STDOUT)

    cg = KPeg::CodeGenerator.new "TestCalc", gram

    code = cg.make("blah[]")
    assert_equal true, code.parse("name")
    assert_equal [:array, [:word, "blah"]], code.result
  end

  def test_invoke_rule_via_another
    parc = KPeg::FormatParser.new(GRAMMAR)
    assert parc.parse, "Unable to parse"

    gram = parc.grammar

    # gr = KPeg::GrammarRenderer.new(gram)
    # puts
    # gr.render(STDOUT)

    cg = KPeg::CodeGenerator.new "TestCalc", gram

    code = cg.make("blah[]")
    assert_equal true, code.parse("root")
    assert_equal [:array, [:word, "blah"]], code.result
  end
end
