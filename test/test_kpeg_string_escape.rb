require 'minitest/autorun'
require 'kpeg'
require 'kpeg/string_escape'

class TestKPegStringEscape < Minitest::Test

  def test_bell
    assert_equal '\b', parse("\b")
  end

  def test_carriage_return
    assert_equal '\r', parse("\r")
  end

  def test_newline
    assert_equal '\n', parse("\n")
  end

  def test_quote
    assert_equal '\\\\\"', parse('\\"')
  end

  def test_slash
    assert_equal '\\\\', parse('\\')
  end

  def test_tab
    assert_equal '\t', parse("\t")
  end

  def parse(str, embed = false)
    se = KPeg::StringEscape.new(str)

    rule = (embed ? 'embed' : nil)

    se.raise_error unless se.parse(rule)

    se.text
  end

end

