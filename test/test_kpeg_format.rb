require 'test/unit'
require 'kpeg'
require 'kpeg/format'
require 'stringio'
require 'rubygems'

class TestKPegFormat < Test::Unit::TestCase
  G = KPeg::FORMAT

  def match(str, gram=nil)
    parc = KPeg::Parser.new(str, G)
    m = parc.parse

    if parc.failed?
      parc.show_error
      raise "Parse failure"
    end

    gram ||= KPeg::Grammar.new
    m ? m.value(gram) : nil
  end

  def test_assignment
    assert_equal [:set, "a", G.ref("b")], match("a=b")
  end

  def test_assignment
    assert_equal [:set, "-", G.ref("b")], match("-=b")
  end

  def test_assigment_sp
    assert_equal [:set, "a", G.ref("b")], match(" a=b")
    assert_equal [:set, "a", G.ref("b")], match(" a =b")
    assert_equal [:set, "a", G.ref("b")], match(" a = b")
    assert_equal [:set, "a", G.ref("b")], match(" a = b ")
  end

  def test_dot
    assert_equal [:set, "a", G.dot], match("a=.")
  end

  def test_string
    assert_equal [:set, "a", G.str("hello")], match('a="hello"')
    assert_equal [:set, "a", G.str("h\"ello")], match('a="h\"ello"')
  end

  def test_regexp
    assert_equal [:set, "a", G.reg(/foo/)], match('a=/foo/')
    assert_equal [:set, "a", G.reg(/foo\/bar/)], match('a=/foo\/bar/')
    assert_equal [:set, "a", G.reg(/[^"]/)], match('a=/[^"]/')
  end

  def test_char_range
    assert_equal [:set, "a", G.range("a", "z")], match('a=[a-z]')
  end

  def test_maybe
    assert_equal [:set, "a", G.maybe(:b)], match('a=b?')
  end

  def test_many
    assert_equal [:set, "a", G.many(:b)], match('a=b+')
  end

  def test_kleene
    assert_equal [:set, "a", G.kleene(:b)], match('a=b*')
  end

  def test_arbitrary_multiple
    assert_equal [:set, "a", G.multiple(:b, 5, 9)], match('a=b[5,9]')
  end

  def test_no_max_multiple
    assert_equal [:set, "a", G.multiple(:b, 5, nil)], match('a=b[5,*]')
  end

  def test_no_max_multiple_sp
    assert_equal [:set, "a", G.multiple(:b, 5, nil)], match('a=b[5, *]')
    assert_equal [:set, "a", G.multiple(:b, 5, nil)], match('a=b[5, * ]')
    assert_equal [:set, "a", G.multiple(:b, 5, nil)], match('a=b[5 , * ]')
    assert_equal [:set, "a", G.multiple(:b, 5, nil)], match('a=b[ 5 , * ]')
  end

  def test_andp
    assert_equal [:set, "a", G.andp(:c)], match('a=&c')
  end

  def test_notp
    assert_equal [:set, "a", G.notp(:c)], match('a=!c')
  end

  def test_choice
    assert_equal [:set, "a", G.any(:b, :c)], match('a=b|c')
  end

  def test_choice_seq_priority
    assert_equal [:set, "a", G.any([:num, :b], :c)], match('a=num b|c')
  end

  def test_choice_sp
    m = match 'a=num "+" dig | dig'
    expected = [:set, "a", G.any([:num, "+", :dig], :dig)]
    assert_equal expected, m
  end

  def test_seq
    m = match 'a=b c'
    assert_equal [:set, "a", G.seq(:b, :c)], m

    m = match 'a=b c d'
    assert_equal [:set, "a", G.seq(:b, :c, :d)], m

    m = match 'a=b c d e f'
    assert_equal [:set, "a", G.seq(:b, :c, :d, :e, :f)], m
  end

  def test_tag
    m = match 'a=b:x'
    assert_equal [:set, "a", G.t(:b, "x")], m
  end

  def test_tag_parens
    m = match 'a=(b c):x'
    assert_equal [:set, "a", G.t([:b, :c], "x")], m
  end

  def test_tag_priority
    m = match 'a=d (b c):x'
    assert_equal [:set, "a", G.seq(:d, G.t([:b, :c], "x"))], m

    m = match 'a=d c*:x'
    assert_equal [:set, "a", G.seq(:d, G.t(G.kleene(:c), "x"))], m
  end

  def test_parens
    m = match 'a=(b c)'
    assert_equal [:set, "a", G.seq(:b, :c)], m
  end

  def test_parens_as_outer
    m = match 'a=b (c|d)'
    assert_equal [:set, "a", G.seq(:b, G.any(:c, :d))], m
  end

  def test_action
    m = match 'a=b c { b + c }'
    assert_equal [:set, "a", G.seq(:b, :c, G.action(" b + c "))], m
  end

  def test_action_nested_curly
    m = match 'a=b c { b + { c + d } }'
    assert_equal [:set, "a", G.seq(:b, :c, G.action(" b + { c + d } "))], m
  end

  def test_multiple_rules
    m = match "a=b\nc=d\ne=f"
    assert_equal [:rules,
       [:set, "a", G.ref("b")], [:rules,
         [:set, "c", G.ref("d")], [:set, "e", G.ref("f")]]], m
  end

  def test_multiline_choice
    gram = <<-GRAM
expr = num "+" num
     | num "-" num
    GRAM

    m = match gram
    expected = [:set, "expr",
                 G.seq(:num, "+", :num) |
                 G.seq(:num, "-", :num)]
    assert_equal expected, m
  end

  def test_multiline_choice_many2
    gram = <<-GRAM
term = term "+" fact
     | term "-" fact
     | fact
fact = fact "*" num
     | fact "/" num
     | num
    GRAM

    m = match gram
    expected =
            [:rules,
              [:set, "term",
                 G.any([:term, "+", :fact],
                       [:term, "-", :fact],
                       :fact)],
              [:set, "fact",
                 G.any([:fact, "*", :num],
                       [:fact, "/", :num],
                       :num)]]

    assert_equal expected, m
  end

  def test_multiline_choice_many
    gram = <<-GRAM
term = term "+" fact
     | term "-" fact
fact = fact "*" num
     | fact "/" num
    GRAM

    m = match gram

    expected =
            [:rules,
              [:set, "term",
                 G.any([:term, "+", :fact],
                       [:term, "-", :fact])],
              [:set, "fact",
                 G.any([:fact, "*", :num],
                       [:fact, "/", :num])]]

    assert_equal expected, m
  end

  def test_roundtrip
    gr = KPeg::GrammarRenderer.new(G)
    io = StringIO.new
    gr.render(io)

    scan = KPeg::Parser.new io.string, G
    m = scan.parse
    if scan.failed?
      puts io.string
      scan.show_error
      assert !scan.failed?, "parsing the grammar"
    end

    g2 = KPeg::Grammar.new
    m.value(g2)

    gr2 = KPeg::GrammarRenderer.new(g2)
    io2 = StringIO.new
    gr2.render(io2)

    unless io.string == io2.string
      require 'tempfile'

      Tempfile.open "diff" do |f1|
        f1 << io.string
        f1.close

        Tempfile.open "diff" do |f2|
          f2 << io2.string
          f2.close

          system "diff -u #{f1.path} #{f2.path}"
        end
      end
    end

    assert_equal io.string, io2.string

    # Go for a 3rd generation!
    scan2 = KPeg::Parser.new io2.string, g2
    m2 = scan2.parse
    assert !scan.failed?, "parsing the grammar"

    g3 = KPeg::Grammar.new
    m2.value(g3)

    # This is as far as we can go. The new parser
    # in m2 has no semantic actions because they've
    # been lost. Until we have the semantic actions
    # in the grammar, this is as far as we can go.
    #
    # If we put the actions in grammar, this will come
    # to life though.
    unless g3.rules.empty?
      gr3 = KPeg::GrammarRenderer.new(g3)
      io3 = StringIO.new
      gr3.render(io3)

      assert_equal io2.string, io3.string

      # INCEPTION! 4! go for 4!
      scan3 = KPeg::Parser.new io3.string, g3
      m3 = scan3.parse
      assert !scan.failed?, "parsing the grammar"

      g4 = KPeg::Grammar.new
      m3.value(g4)

      gr4 = KPeg::GrammarRenderer.new(g4)
      io4 = StringIO.new
      gr4.render(io4)

      assert_equal io3.string, io4.string
    end
  end
end
