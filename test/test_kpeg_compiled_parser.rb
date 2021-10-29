require 'minitest/autorun'
require 'kpeg'
require 'kpeg/compiled_parser'
require 'stringio'

class TestKPegCompiledParser < Minitest::Test

  gram = <<-GRAM
  letter = [a-z]
  number = [0-9]
  root = letter
  GRAM

  KPeg.compile gram, "TestParser", self

  gram = <<-GRAM
  %test = TestKPegCompiledParser::TestParser
  root = %test.letter %test.number? "!"
  GRAM

  KPeg.compile gram, "CompTestParser", self

  def test_current_column
    r = TestParser.new "hello\nsir"
    assert_equal 2, r.current_column(1)
    assert_equal 6, r.current_column(5)
    assert_equal 1, r.current_column(7)
    assert_equal 4, r.current_column(10)
  end

  def test_failed_rule
    r = TestParser.new "9"
    assert !r.parse, "shouldn't parse"

    assert_equal :_letter, r.failed_rule
  end

  def test_failure_info
    r = TestParser.new "9"
    assert !r.parse, "shouldn't parse"

    expected = "line 1, column 1: failed rule 'letter' = '[a-z]'"
    assert_equal 0, r.failing_rule_offset
    assert_equal expected, r.failure_info
  end

  def test_failure_caret
    r = TestParser.new "9"
    assert !r.parse, "shouldn't parse"

    assert_equal "9\n^", r.failure_caret
  end

  def test_failure_character
    r = TestParser.new "9"
    assert !r.parse, "shouldn't parse"

    assert_equal "9", r.failure_character
  end

  def test_failure_oneline
    r = TestParser.new "9"
    assert !r.parse, "shouldn't parse"

    expected = "@1:1 failed rule 'letter', got '9'"
    assert_equal expected, r.failure_oneline
  end

  def test_composite_grammar
    r = CompTestParser.new "l!"
    assert r.parse, "should parse"
  end

  def test_composite_grammar_failure
    r = CompTestParser.new "9"
    assert !r.parse, "should parse"

    expected = "@1:1 failed rule 'TestKPegCompiledParser::TestParser#_letter', got '9'"
    assert_equal expected, r.failure_oneline
  end

  def test_composite_two_char_error
    r = CompTestParser.new "aa"
    assert_nil r.parse, "should not parse"

    expected = "@1:2 failed rule 'TestKPegCompiledParser::TestParser#_number', got 'a'"
    assert_equal expected, r.failure_oneline
  end

end
