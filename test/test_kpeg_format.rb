require 'test/unit'
require 'kpeg'
require 'kpeg/format_parser'
require 'kpeg/grammar_renderer'
require 'stringio'
require 'rubygems'

class TestKPegFormat < Test::Unit::TestCase
  G = KPeg::Grammar.new

  gram = File.read File.expand_path("../../lib/kpeg/format.kpeg", __FILE__)
  KPeg.compile gram, "TestParser", self

  def match(str, gram=nil, log=false)
    parc = TestParser.new str
    parc.raise_error unless parc.parse

    return parc.grammar
  end

  def assert_rule(expect, gram, name="a")
    actual = gram.find name.to_s
    assert_equal expect, actual.op
  end

  def test_assignment
    assert_rule G.ref("b"), match("a=b"), "a"
  end

  def test_invoke
    assert_rule G.invoke("b"), match("a=@b"), "a"
  end

  def test_assignment_hyphen_only
    assert_rule G.ref("b"), match("-=b"), "-"
  end

  def test_assigment_sp
    assert_rule G.ref("b"), match(" a=b")
    assert_rule G.ref("b"), match(" a =b")
    assert_rule G.ref("b"), match(" a = b")
    assert_rule G.ref("b"), match(" a = b ")
  end

  def test_assign_with_arg
    gram = match("a(t) = b")
    rule = gram.find "a"
    assert_equal ["t"], rule.arguments
  end

  def test_assign_with_arg_disambiguated_from_grouping
    str = <<-STR
a = c
b(p) = x
    STR

    gram = match(str)
  end

  def test_assign_with_multiple_args
    gram = match("a(t,x) = b")
    rule = gram.find "a"
    assert_equal ["t", "x"], rule.arguments
  end

  def test_assign_with_args_spacing
    gram = match("a( t) = b")
    rule = gram.find "a"
    assert_equal ["t"], rule.arguments

    gram = match("a( t ) = b")
    rule = gram.find "a"
    assert_equal ["t"], rule.arguments

    gram = match("a( t,x) = b")
    rule = gram.find "a"
    assert_equal ["t", "x"], rule.arguments

    gram = match("a( t,x ) = b")
    rule = gram.find "a"
    assert_equal ["t", "x"], rule.arguments

    gram = match("a( t ,x ) = b")
    rule = gram.find "a"
    assert_equal ["t", "x"], rule.arguments

    gram = match("a( t , x ) = b")
    rule = gram.find "a"
    assert_equal ["t", "x"], rule.arguments
  end

  def test_invoke_with_arg
    gram = match("a=b(1)")
    rule = gram.find "a"
    assert_equal "(1)", rule.op.arguments
  end

  def test_invoke_with_double_quoted_strings
    m = match "a=b(\")\")"
    assert_equal "(\")\")", m.find("a").op.arguments
  end

  def test_invoke_with_single_quoted_strings
    m = match "a=b(')')"
    assert_equal "(')')", m.find("a").op.arguments
  end


  def test_invoke_with_multiple_args
    assert_rule G.invoke("b", "(1,2)"), match("a=b(1,2)"), "a"
  end

  def test_invoke_foreign_rule
    assert_rule G.foreign_invoke("blah", "letters"),
                match("a=%blah.letters"), "a"
  end

  def test_add_foreign_grammar
    gram = match "%blah = OtherGrammar"
    assert_equal "OtherGrammar", gram.foreign_grammars["blah"]
  end

  def test_add_foreign_grammar_with_numbers
    gram = match "%blah = Thing1::OtherGrammar"
    assert_equal "Thing1::OtherGrammar", gram.foreign_grammars["blah"]
  end

  def test_add_foreign_grammar_with_undescore
    gram = match "%blah = Other_Grammar"
    assert_equal "Other_Grammar", gram.foreign_grammars["blah"]
  end

  def test_invoke_parent_rule
    assert_rule G.foreign_invoke("parent", "letters"),
                match("a=^letters"), "a"
  end

  def test_dot
    assert_rule G.dot, match("a=.")
  end

  def test_string
    assert_rule G.str(""), match('a=""')
    assert_rule G.str("hello"), match('a="hello"')
    assert_rule G.str("hello\ngoodbye"), match('a="hello\ngoodbye"')
    assert_rule G.str("\n\s\r\t\v\f\b\a\r\\\"\012\x1b"),
                match('a="\n\s\r\t\v\f\b\a\r\\\\\\"\012\x1b"')
    assert_rule G.str("h\"ello"), match('a="h\"ello"')
  end

  def test_regexp
    assert_rule G.reg(/foo/), match('a=/foo/')
    assert_rule G.reg(/foo\/bar/), match('a=/foo\/bar/')
    assert_rule G.reg(/[^"]/), match('a=/[^"]/')
  end

  def test_regexp_options
    if RUBY_VERSION > "1.8.7"
      assert_rule G.reg(/foo/n), match('a=/foo/n')    
    else
      assert_rule G.reg(/foo/u), match('a=/foo/u')
    end
  end

  def test_char_range
    assert_rule G.range("a", "z"), match('a=[a-z]')
  end

  def test_maybe
    assert_rule G.maybe(:b), match('a=b?')
  end

  def test_many
    assert_rule G.many(:b), match('a=b+')
  end

  def test_many_sequence
    assert_rule G.many([:b, :c]), match('a=(b c)+')
  end

  def test_many_sequence_with_action
    assert_rule G.seq(G.many([:b, :c]), G.action(" 1 ")), 
                                   match('a=(b c)+ { 1 }')
  end

  def test_kleene
    assert_rule G.kleene(:b), match('a=b*')
  end

  def test_arbitrary_multiple
    assert_rule G.multiple(:b, 5, 9), match('a=b[5,9]')
  end
  
  def test_single_value_for_multiple
    assert_rule G.multiple(:b, 5, 5), match('a=b[5]')
  end

  def test_no_max_multiple
    assert_rule G.multiple(:b, 5, nil), match('a=b[5,*]')
  end

  def test_no_max_multiple_sp
    assert_rule G.multiple(:b, 5, nil), match('a=b[5, *]')
    assert_rule G.multiple(:b, 5, nil), match('a=b[5, * ]')
    assert_rule G.multiple(:b, 5, nil), match('a=b[5 , * ]')
    assert_rule G.multiple(:b, 5, nil), match('a=b[ 5 , * ]')
  end

  def test_andp
    assert_rule G.andp(:c), match('a=&c')
  end

  def test_notp
    assert_rule G.notp(:c), match('a=!c')
  end

  def test_choice
    assert_rule G.any(:b, :c), match('a=b|c')
  end

  def test_choice_seq_priority
    assert_rule G.any([:num, :b], :c), match('a=num b|c')
  end

  def test_choice_sp
    m = match 'a=num "+" dig | dig'
    expected = G.any([:num, "+", :dig], :dig)
    assert_rule expected, m
  end

  def test_choice_sp2
    str = <<-STR
Stmt    = - Expr:e EOL
        | ( !EOL . )* EOL
    STR
    m = match str
    expected = G.any(
                  [:"-", G.t(:Expr, "e"), :EOL],
                  [G.kleene([G.notp(:EOL), G.dot]), :EOL])

    assert_rule expected, m, "Stmt"
  end

  def test_choice_with_actions
    str = <<-STR
Stmt    = - Expr:e EOL                  { p e }
        | ( !EOL . )* EOL               { puts "error" }
    STR
    m = match str
    expected = G.any(
                  [:"-", G.t(:Expr, "e"), :EOL, G.action(" p e ")],
                  [G.kleene([G.notp(:EOL), G.dot]), :EOL,
                   G.action(" puts \"error\" ")])

    assert_rule expected, m, "Stmt"
  end

  def test_multiline_seq
    str = <<-STR
Sum     = Product:l
                ( PLUS  Product:r       { l += r }
                | MINUS Product:r       { l -= r }
                )*                      { l }
    STR
    m = match str
    expected = G.seq(
                  G.t(:Product, "l"),
                  G.kleene(
                    G.any(
                      [:PLUS, G.t(:Product, "r"),  G.action(" l += r ")],
                      [:MINUS, G.t(:Product, "r"), G.action(" l -= r ")]
                    )),
                  G.action(" l "))

    assert_rule expected, m, "Sum"
  end

  def test_multiline_seq2
    str = <<-STR
Value   = NUMBER:i                      { i }
        | ID:i !ASSIGN                  { vars[i] }
        | OPEN Expr:i CLOSE             { i }
    STR
    m = match(str)
  end

  def test_seq
    m = match 'a=b c'
    assert_rule G.seq(:b, :c), m

    m = match 'a=b c d'
    assert_rule G.seq(:b, :c, :d), m

    m = match 'a=b c d e f'
    assert_rule G.seq(:b, :c, :d, :e, :f), m
  end

  def test_tag
    m = match 'a=b:x'
    assert_rule G.t(:b, "x"), m
  end

  def test_tag_parens
    m = match 'a=(b c):x'
    assert_rule G.t([:b, :c], "x"), m
  end

  def test_tag_priority
    m = match 'a=d (b c):x'
    assert_rule G.seq(:d, G.t([:b, :c], "x")), m

    m = match 'a=d c*:x'
    assert_rule G.seq(:d, G.t(G.kleene(:c), "x")), m
  end

  def test_parens
    m = match 'a=(b c)'
    assert_rule G.seq(:b, :c), m
  end

  def test_parens_sp
    m = match 'a=( b c )'
    assert_rule G.seq(:b, :c), m
  end

  def test_parens_as_outer
    m = match 'a=b (c|d)'
    assert_rule G.seq(:b, G.any(:c, :d)), m
  end

  def test_action
    m = match 'a=b c { b + c }'
    assert_rule G.seq(:b, :c, G.action(" b + c ")), m
  end

  def test_action_nested_curly
    m = match 'a=b c { b + { c + d } }'
    assert_rule G.seq(:b, :c, G.action(" b + { c + d } ")), m
  end

  def test_actions_handle_double_quoted_strings
    m = match 'a=b c { b + c + "}" }'
    assert_rule G.seq(:b, :c, G.action(' b + c + "}" ')), m
  end

  def test_actions_handle_single_quoted_strings
    m = match "a=b c { b + c + '}' }"
    assert_rule G.seq(:b, :c, G.action(" b + c + '}' ")), m
  end

  def test_action_send
    m = match 'a=b c ~d'
    assert_rule G.seq(:b, :c, G.action("d")), m
  end

  def test_action_send_with_args
    m = match 'a=b c ~d(b,c)'
    assert_rule G.seq(:b, :c, G.action("d(b,c)")), m
  end

  def test_collect
    m = match 'a = < b c >'
    assert_rule G.collect(G.seq(:b, :c)), m
  end

  def test_bounds
    m = match 'a = @< b c >'
    assert_rule G.bounds(G.seq(:b, :c)), m
  end

  def test_comment
    m = match "a=b # this is a comment\n"
    assert_rule G.ref('b'), m
  end

  def test_comment_span
    m = match "a=b # this is a comment\n   c"
    assert_rule G.seq(G.ref('b'), G.ref("c")), m
  end

  def test_parser_setup
    m = match "%% { def initialize; end }\na=b"
    assert_rule G.ref("b"), m
    assert_equal " def initialize; end ", m.setup_actions.first.action
  end

  def test_parser_name
    m = match "%%name = BlahParser"
    assert_equal "BlahParser", m.variables["name"]
  end

  def test_multiple_rules
    m = match "a=b\nc=d\ne=f"
    assert_rule G.ref("b"), m, "a"
    assert_rule G.ref("d"), m, "c"
    assert_rule G.ref("f"), m, "e"
  end

  def test_multiline_choice
    gram = <<-GRAM
expr = num "+" num
     | num "-" num
    GRAM

    m = match gram
    expected = G.seq(:num, "+", :num) |
               G.seq(:num, "-", :num)
    assert_rule expected, m, "expr"
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
    term = G.any([:term, "+", :fact],
                 [:term, "-", :fact],
                  :fact)
    fact = G.any([:fact, "*", :num],
                  [:fact, "/", :num],
                   :num)

    assert_equal term, m.find("term").op
    assert_equal fact, m.find("fact").op
  end

  def test_multiline_choice_many
    gram = <<-GRAM
term = term "+" fact
     | term "-" fact
fact = fact "*" num
     | fact "/" num
    GRAM

    m = match gram
    term = G.any([:term, "+", :fact],
                 [:term, "-", :fact])
    fact = G.any([:fact, "*", :num],
                  [:fact, "/", :num])

    assert_equal term, m.find("term").op
    assert_equal fact, m.find("fact").op
  end

  def make_parser(str, gram, debug=false)
    cg = KPeg::CodeGenerator.new "Test", gram, debug
    inst = cg.make(str)
    return inst
  end

  def test_allow_ends_with_comment
    path = File.expand_path("../inputs/comments.kpeg", __FILE__)
    parser = KPeg::FormatParser.new File.read(path), true
    assert true, parser.parse
  end

  def test_roundtrip
    path = File.expand_path("../../lib/kpeg/format.kpeg", __FILE__)
    parser = KPeg::FormatParser.new File.read(path)
    assert parser.parse, "Unable to parse"

    start = parser.grammar

    gr = KPeg::GrammarRenderer.new(start)
    io = StringIO.new
    gr.render(io)

    scan = make_parser io.string, start
    unless scan.parse
      puts io.string
      scan.show_error
      assert !scan.failed?, "parsing the grammar"
    end

    g2 = scan.grammar

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
    scan2 = make_parser io2.string, g2
    assert scan2.parse, "parsing the grammar"

    g3 = scan2.grammar

    unless g3.rules.empty?
      gr3 = KPeg::GrammarRenderer.new(g3)
      io3 = StringIO.new
      gr3.render(io3)

      assert_equal io2.string, io3.string

      # INCEPTION! 4! go for 4!
      scan3 = make_parser io3.string, g3
      assert scan3.parse, "parsing the grammar"

      g4 = scan3.grammar

      gr4 = KPeg::GrammarRenderer.new(g4)
      io4 = StringIO.new
      gr4.render(io4)

      assert_equal io3.string, io4.string
    end
  end
end
