require 'test/unit'
require 'kpeg'
require 'kpeg/compiled_parser'
require 'stringio'

class TestKPegCompiledParser < Test::Unit::TestCase

  gram = <<-GRAM
  letter = [a-z]
  root = letter
  GRAM


  KPeg.compile gram, "TestParser", self

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

end
