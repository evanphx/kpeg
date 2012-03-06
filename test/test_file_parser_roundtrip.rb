require 'minitest/autorun'
require 'kpeg'
require 'kpeg/format_parser'
require 'kpeg/grammar_renderer'
require 'kpeg/code_generator'
require 'stringio'

class TestKPegRoundtrip < MiniTest::Unit::TestCase
  PATH = File.expand_path("../../lib/kpeg/format.kpeg", __FILE__)
  def test_roundtrip
    data = File.read(PATH)

    pr = KPeg::FormatParser.new data
    assert pr.parse, "Couldn't parse with builtin parser"

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(pr.g)
    gr.render io

    cg1 = KPeg::CodeGenerator.new("Test1", pr.g, false)
    pr2 = cg1.make(io.string)
    g2 = KPeg::Grammar.new
    pr2.instance_variable_set(:@g, g2)

    assert pr2.parse, "Couldn't parse with 2nd generation parser"

    io2 = StringIO.new
    gr2 = KPeg::GrammarRenderer.new(g2)
    gr2.render io2

    assert_equal io2.string, io.string

    cg2 = KPeg::CodeGenerator.new("Test2", g2, false)
    pr3 = cg2.make(io2.string)
    g3 = KPeg::Grammar.new
    pr3.instance_variable_set(:@g, g3)

    assert pr3.parse, "Couldn't parse with 3rd generation parser"

    io3 = StringIO.new
    gr3 = KPeg::GrammarRenderer.new(g3)
    gr3.render io3

    assert_equal io3.string, io2.string

    cg3 = KPeg::CodeGenerator.new("Test3", g3, false)
    pr4 = cg3.make(io3.string)
    g4 = KPeg::Grammar.new
    pr4.instance_variable_set(:@g, g4)

    assert pr4.parse, "Couldn't parse with 4th generation parser"

    io4 = StringIO.new
    gr4 = KPeg::GrammarRenderer.new(g4)
    gr4.render io4

    assert_equal io4.string, io3.string
  end

  def test_roundtrip_standalone
    data = File.read(PATH)

    pr = KPeg::FormatParser.new data
    assert pr.parse, "Couldn't parse with builtin parser"

    io = StringIO.new
    gr = KPeg::GrammarRenderer.new(pr.g)
    gr.render io

    cg1 = KPeg::CodeGenerator.new("Test1", pr.g, false)
    cg1.standalone = true
    pr2 = cg1.make(io.string)
    g2 = KPeg::Grammar.new
    pr2.instance_variable_set(:@g, g2)

    assert pr2.parse, "Couldn't parse with 2nd generation parser"

    io2 = StringIO.new
    gr2 = KPeg::GrammarRenderer.new(g2)
    gr2.render io2

    assert_equal io2.string, io.string

    cg2 = KPeg::CodeGenerator.new("Test2", g2, false)
    cg2.standalone = true
    pr3 = cg2.make(io2.string)
    g3 = KPeg::Grammar.new
    pr3.instance_variable_set(:@g, g3)

    assert pr3.parse, "Couldn't parse with 3rd generation parser"

    io3 = StringIO.new
    gr3 = KPeg::GrammarRenderer.new(g3)
    gr3.render io3

    assert_equal io3.string, io2.string

    cg3 = KPeg::CodeGenerator.new("Test3", g3, false)
    cg3.standalone = true
    pr4 = cg3.make(io3.string)
    g4 = KPeg::Grammar.new
    pr4.instance_variable_set(:@g, g4)

    assert pr4.parse, "Couldn't parse with 4th generation parser"

    io4 = StringIO.new
    gr4 = KPeg::GrammarRenderer.new(g4)
    gr4.render io4

    assert_equal io4.string, io3.string
  end
end
