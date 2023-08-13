# encoding: utf-8
require 'minitest/autorun'
require 'kpeg'
require 'kpeg/code_generator'
require 'stringio'

class TestKPegCodeGenerator < Minitest::Test
  def test_dot
    gram = KPeg.grammar do |g|
      g.root = g.dot
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = .
  def _root
    get_byte or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_str
    gram = KPeg.grammar do |g|
      g.root = g.str("hello")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = "hello"
  def _root
    match_string("hello") or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_reg
    gram = KPeg.grammar do |g|
      g.root = g.reg(/[0-9]/)
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = /[0-9]/
  def _root
    scan(/\\G(?-mix:[0-9])/) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "/[0-9]/")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("9")
    assert cg.parse("1")
    assert !cg.parse("a")
  end

  def test_reg_unicode
    gram = KPeg.grammar do |g|
      g.root = g.reg(/./u)
    end
    
    if RUBY_VERSION > "1.8.7"
    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = /./
  def _root
    scan(/\\G(?-mix:.)/) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "/./")
  # :startdoc:
end
    STR
    else
    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = /./u
  def _root
    scan(/\\G(?-mix:.)/u) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "/./u")
  # :startdoc:
end
    STR
    end
    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("う")
    assert cg.parse("a")
  end

  def test_char_range
    gram = KPeg.grammar do |g|
      g.root = g.range("a", "z")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = [a-z]
  def _root
    sequence(self.pos, (  # char range
      _tmp = get_byte
      _tmp && _tmp >= 97 && _tmp <= 122
    )) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "[a-z]")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("z")
    assert cg.parse("a")
    assert !cg.parse("0")
  end

  def test_char_range_in_seq
    gram = KPeg.grammar do |g|
      g.root = g.seq(g.range("a", "z"), "hello")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = [a-z] "hello"
  def _root
    sequence(self.pos,  # sequence
      sequence(self.pos, (  # char range
        _tmp = get_byte
        _tmp && _tmp >= 97 && _tmp <= 122
      )) &&
      match_string("hello")  # end sequence
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "[a-z] \\\"hello\\\"")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("ahello")
    assert cg.parse("zhello")
    assert !cg.parse("0hello")
    assert !cg.parse("ajello")
  end

  def test_any
    gram = KPeg.grammar do |g|
      g.root = g.any("hello", "world")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = ("hello" | "world")
  def _root
    ( # choice
      match_string("hello") ||
      match_string("world")
      # end choice
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "(\\\"hello\\\" | \\\"world\\\")")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
    assert cg.parse("world")
    assert !cg.parse("jello")
  end

  def test_any_resets_pos
    gram = KPeg.grammar do |g|
      g.root = g.any(g.seq("hello", "world"), "hello balloons")
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    code = cg.make("helloworld")
    assert code.parse
    assert_equal 10, code.pos

    assert cg.parse("hello balloons")
  end

  def test_maybe
    gram = KPeg.grammar do |g|
      g.root = g.maybe("hello")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = "hello"?
  def _root
    (  # optional
      match_string("hello") ||
      true  # end optional
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"?")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
    assert cg.parse("jello")
  end

  def test_maybe_resets_pos
    gram = KPeg.grammar do |g|
      g.root = g.maybe(g.seq("hello", "world"))
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    assert cg.parse("helloworld")

    code = cg.make("hellojello")
    assert code.parse
    assert_equal 0, code.pos
  end

  def test_kleene
    gram = KPeg.grammar do |g|
      g.root = g.kleene("hello")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = "hello"*
  def _root
    while true  # kleene
      match_string("hello") || (break true) # end kleene
    end or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"*")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hellohellohello")
    assert code.parse
    assert_equal 15, code.pos
  end

  def test_kleene_reset_pos
    gram = KPeg.grammar do |g|
      g.root = g.kleene(g.seq("hello", "world"))
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    code = cg.make("helloworldhelloworld")
    assert code.parse
    assert_equal 20, code.pos

    code = cg.make("hellojello")
    assert code.parse
    assert_equal 0, code.pos
  end

  def test_many
    gram = KPeg.grammar do |g|
      g.root = g.many("hello")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = "hello"+
  def _root
    loop_range(1.., false) {
      match_string("hello")
    } or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"+")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hellohello")
    assert code.parse
    assert_equal 10, code.pos

    code = cg.make("hello")
    assert code.parse
    assert_equal 5, code.pos

    code = cg.make("")
    assert !code.parse
  end

  def test_many_resets_pos
    gram = KPeg.grammar do |g|
      g.root = g.many(g.seq("hello", "world"))
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    code = cg.make("helloworldhelloworld")
    assert code.parse
    assert_equal 20, code.pos

    code = cg.make("hellojello")
    assert !code.parse
    assert_equal 0, code.pos
  end

  def test_multiple
    gram = KPeg.grammar do |g|
      g.root = g.multiple("hello", 5, 9)
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = "hello"[5, 9]
  def _root
    loop_range(5..9, false) {
      match_string("hello")
    } or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"[5, 9]")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_seq
    gram = KPeg.grammar do |g|
      g.root = g.seq("hello", "world")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = "hello" "world"
  def _root
    sequence(self.pos,  # sequence
      match_string("hello") &&
      match_string("world")  # end sequence
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\" \\\"world\\\"")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_seq_resets_pos
    gram = KPeg.grammar do |g|
      g.root = g.seq("hello", "world")
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    code = cg.make("helloworld")
    assert code.parse

    code = cg.make("hellojello")
    assert !code.parse
    assert_equal 0, code.pos
  end

  def test_andp
    gram = KPeg.grammar do |g|
      g.root = g.andp("hello")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = &"hello"
  def _root
    look_ahead(self.pos,
      match_string("hello")  # end look ahead
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "&\\\"hello\\\"")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert code.parse
    assert_equal 0, code.pos

    code = cg.make("jello")
    assert !code.parse
    assert_equal 0, code.pos
  end

  def test_andp_for_action
    gram = KPeg.grammar do |g|
      g.root = g.andp(g.action(" !defined? @fail "))
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = &{ !defined? @fail }
  def _root
    look_ahead(self.pos,
      !defined? @fail  # end look ahead
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "&{ !defined? @fail }")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert code.parse
    assert_equal 0, code.pos

    code = cg.make("jello")
    code.instance_variable_set :@fail, true
    assert !code.parse
    assert_equal 0, code.pos
  end

  def test_notp
    gram = KPeg.grammar do |g|
      g.root = g.notp("hello")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = !"hello"
  def _root
    look_negation(self.pos,
      match_string("hello")  # end negation
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "!\\\"hello\\\"")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert !code.parse
    assert_equal 0, code.pos

    code = cg.make("jello")
    assert code.parse
    assert_equal 0, code.pos
  end

  def test_notp_for_action
    gram = KPeg.grammar do |g|
      g.root = g.notp(g.action(" defined? @fail "))
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = !{ defined? @fail }
  def _root
    look_negation(self.pos,
      defined? @fail  # end negation
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "!{ defined? @fail }")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert code.parse
    assert_equal 0, code.pos

    code = cg.make("jello")
    code.instance_variable_set :@fail, true
    assert !code.parse
    assert_equal 0, code.pos
  end


  def test_ref
    gram = KPeg.grammar do |g|
      g.greeting = "hello"
      g.root = g.ref("greeting")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # greeting = "hello"
  def _greeting
    match_string("hello") or set_failed_rule :_greeting
  end

  # root = greeting
  def _root
    apply(:_greeting) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_greeting] = rule_info("greeting", "\\\"hello\\\"")
  Rules[:_root] = rule_info("root", "greeting")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_invoke
    gram = KPeg.grammar do |g|
      g.greeting = "hello"
      g.root = g.invoke("greeting")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # greeting = "hello"
  def _greeting
    match_string("hello") or set_failed_rule :_greeting
  end

  # root = @greeting
  def _root
    _greeting() or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_greeting] = rule_info("greeting", "\\\"hello\\\"")
  Rules[:_root] = rule_info("root", "@greeting")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_invoke_with_args
    gram = KPeg.grammar do |g|
      g.set("greeting", "hello", ["a", "b"])
      g.root = g.invoke("greeting", "(1,2)")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # greeting = "hello"
  def _greeting(a,b)
    match_string("hello") or set_failed_rule :_greeting
  end

  # root = @greeting(1,2)
  def _root
    _greeting(1,2) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_greeting] = rule_info("greeting", "\\\"hello\\\"")
  Rules[:_root] = rule_info("root", "@greeting(1,2)")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  gram = <<-GRAM
  greeting = "hello"
  greeting2(a,b) = "hello"
  GRAM

  KPeg.compile gram, "TestParser", self

  def test_foreign_invoke
    gram = KPeg.grammar do |g|
      g.add_foreign_grammar "blah", "TestKPegCodeGenerator::TestParser"
      g.root = g.foreign_invoke("blah", "greeting")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:
  def setup_foreign_grammar
    @_grammar_blah = TestKPegCodeGenerator::TestParser.new(nil)
  end

  # root = %blah.greeting
  def _root
    @_grammar_blah.external_invoke(self, :_greeting) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "%blah.greeting")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_foreign_invoke_with_args
    gram = KPeg.grammar do |g|
      g.add_foreign_grammar "blah", "TestKPegCodeGenerator::TestParser"
      g.root = g.foreign_invoke("blah", "greeting2", "(1,2)")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:
  def setup_foreign_grammar
    @_grammar_blah = TestKPegCodeGenerator::TestParser.new(nil)
  end

  # root = %blah.greeting2(1,2)
  def _root
    @_grammar_blah.external_invoke(self, :_greeting2, 1,2) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "%blah.greeting2(1,2)")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_tag
    gram = KPeg.grammar do |g|
      g.root = g.t g.str("hello"), "t"
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = "hello":t
  def _root
    match_string("hello") &&
    ( t = @result; true ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\":t")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_noname_tag
    gram = KPeg.grammar do |g|
      g.root = g.t g.str("hello")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = "hello"
  def _root
    match_string("hello") or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output
  end

  def test_tag_maybe
    gram = KPeg.grammar do |g|
      g.hello = g.seq(g.collect("hello"), g.action("text"))
      g.root = g.seq g.t(g.maybe(:hello), "lots"), g.action("lots")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # hello = < "hello" > {text}
  def _hello
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        match_string("hello") &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_hello
  end

  # root = hello?:lots {lots}
  def _root
    sequence(self.pos,  # sequence
      (  # optional
        apply(:_hello) ||
        ( @result = nil; true )  # end optional
      ) &&
      ( lots = @result; true ) &&
      ( @result = (lots); true )  # end sequence
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_hello] = rule_info("hello", "< \\\"hello\\\" > {text}")
  Rules[:_root] = rule_info("root", "hello?:lots {lots}")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert code.parse
    assert_equal "hello", code.result

    code = cg.make("")
    assert code.parse
    assert_nil code.result
  end


  def test_tag_multiple
    gram = KPeg.grammar do |g|
      g.hello = g.seq(g.collect("hello"), g.action("text"))
      g.root = g.seq g.t(g.kleene(:hello), "lots"), g.action("lots")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # hello = < "hello" > {text}
  def _hello
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        match_string("hello") &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_hello
  end

  # root = hello*:lots {lots}
  def _root
    sequence(self.pos,  # sequence
      loop_range(0.., true) {
        apply(:_hello)
      } &&
      ( lots = @result; true ) &&
      ( @result = (lots); true )  # end sequence
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_hello] = rule_info("hello", "< \\\"hello\\\" > {text}")
  Rules[:_root] = rule_info("root", "hello*:lots {lots}")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hellohello")
    assert code.parse
    assert_equal ["hello", "hello"], code.result

    code = cg.make("hello")
    assert code.parse
    assert_equal ["hello"], code.result

    code = cg.make("")
    assert code.parse
    assert_equal [], code.result
  end

  def test_tag_many
    gram = KPeg.grammar do |g|
      g.hello = g.seq(g.collect("hello"), g.action("text"))
      g.root = g.seq g.t(g.many(:hello), "lots"), g.action("lots")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # hello = < "hello" > {text}
  def _hello
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        match_string("hello") &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_hello
  end

  # root = hello+:lots {lots}
  def _root
    sequence(self.pos,  # sequence
      loop_range(1.., true) {
        apply(:_hello)
      } &&
      ( lots = @result; true ) &&
      ( @result = (lots); true )  # end sequence
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_hello] = rule_info("hello", "< \\\"hello\\\" > {text}")
  Rules[:_root] = rule_info("root", "hello+:lots {lots}")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hellohello")
    assert code.parse
    assert_equal ["hello", "hello"], code.result

    code = cg.make("hello")
    assert code.parse
    assert_equal ["hello"], code.result

    code = cg.make("")
    assert !code.parse
  end

  def test_action
    gram = KPeg.grammar do |g|
      g.root = g.action "3 + 4"
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = {3 + 4}
  def _root
    ( @result = (3 + 4); true ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "{3 + 4}")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("")
    assert code.parse
    assert_equal 7, code.result
  end

  def test_collect
    gram = KPeg.grammar do |g|
      g.root = g.seq(g.collect("hello"), g.action(" text "))
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = < "hello" > { text }
  def _root
    sequence(self.pos,  # sequence
      ( _text_start = self.pos
        match_string("hello") &&
        ( text = get_text(_text_start); true )
      ) &&
      ( @result = (text); true )  # end sequence
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "< \\\"hello\\\" > { text }")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert code.parse
    assert_equal "hello", code.result
  end

  def test_bounds
    gram = KPeg.grammar do |g|
      g.root = g.seq(g.bounds("hello"), g.action(" bounds "))
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = @< "hello" > { bounds }
  def _root
    sequence(self.pos,  # sequence
      ( _bounds_start = self.pos
        match_string("hello") &&
        (bounds = [_bounds_start, self.pos]; true )
      ) &&
      ( @result = (bounds); true )  # end sequence
    ) or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "@< \\\"hello\\\" > { bounds }")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert code.parse
    assert_equal [0,5], code.result
  end

  def test_standalone_region
    gram = KPeg.grammar do |g|
      g.root = g.dot
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    expected = <<-EXPECTED

    # This is distinct from setup_parser so that a standalone parser
    # can redefine #initialize and still have access to the proper
    # parser setup code.
    def initialize(str, debug=false)
      setup_parser(str, debug)
    end

    EXPECTED

    assert_equal expected,
                 cg.standalone_region('compiled_parser.rb', 'INITIALIZE')
  end

  def test_parse_error
    gram = KPeg.grammar do |g|
      g.world = "world"
      g.root = g.seq("hello", :world)
    end

    cg = KPeg::CodeGenerator.new "Test", gram

    code = cg.make("no")
    assert !code.parse
    assert_equal 0, code.failing_rule_offset

    cg2 = KPeg::CodeGenerator.new "Test", gram

    code = cg2.make("hellono")
    assert !code.parse
    assert_equal 5, code.failing_rule_offset
  end

  def test_directive_footer
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.directives['footer'] = g.action("\n# require 'some/subclass'\n")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = .
  def _root
    get_byte or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
  # :startdoc:
end

# require 'some/subclass'
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_directive_header
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.directives['header'] = g.action("\n# coding: UTF-8\n")
    end

    str = <<-STR
# coding: UTF-8
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = .
  def _root
    get_byte or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_directive_pre_class
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.directives['pre-class'] = g.action("\n# some comment\n")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

# some comment
class Test < KPeg::CompiledParser
  # :stopdoc:

  # root = .
  def _root
    get_byte or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_directive_pre_class_standalone
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.directives['pre-class'] = g.action("\n# some comment\n")
    end

    cg = KPeg::CodeGenerator.new "Test", gram
    cg.standalone = true

    assert_match %r%^# some comment%, cg.output
  end

  def test_setup_actions
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.add_setup g.action(" attr_reader :foo ")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser

 attr_reader :foo 

  # :stopdoc:

  # root = .
  def _root
    get_byte or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_output_standalone
    gram = KPeg.grammar do |g|
      g.root = g.dot
    end

    cg = KPeg::CodeGenerator.new "Test", gram
    cg.standalone = true

    # if this fails, also change test_variable_custom_initialize
    assert_match 'def initialize(str, debug=false)', cg.output

    assert_match '# :stopdoc:', cg.output
    assert_match '# :startdoc:', cg.output

    assert cg.parse("hello")
  end

  def test_variable_custom_initialize
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.variables['custom_initialize'] = 'whatever'
    end

    cg = KPeg::CodeGenerator.new "Test", gram
    cg.standalone = true

    refute_match 'def initialize(str, debug=false)', cg.output
  end

  def test_ast_generation
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.set_variable "bracket", "ast BracketOperator(receiver, argument)"
      g.set_variable "simple", "ast Simple()"
      g.set_variable "simple2", "ast Simple2"
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  module AST
    class Node; end
    class BracketOperator < Node
      def initialize(receiver, argument)
        @receiver = receiver
        @argument = argument
      end
      attr_reader :receiver
      attr_reader :argument
    end
    class Simple < Node
      def initialize()
      end
    end
    class Simple2 < Node
      def initialize()
      end
    end
  end
  module ASTConstruction
    def bracket(receiver, argument)
      AST::BracketOperator.new(receiver, argument)
    end
    def simple()
      AST::Simple.new()
    end
    def simple2()
      AST::Simple2.new()
    end
  end
  include ASTConstruction

  # root = .
  def _root
    get_byte or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

  def test_ast_generation_in_different_location
    gram = KPeg.grammar do |g|
      g.root = g.dot
      g.set_variable "bracket", "ast BracketOperator(receiver, argument)"
      g.set_variable "ast-location", "MegaAST"
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser
  # :stopdoc:

  module MegaAST
    class Node; end
    class BracketOperator < Node
      def initialize(receiver, argument)
        @receiver = receiver
        @argument = argument
      end
      attr_reader :receiver
      attr_reader :argument
    end
  end
  module MegaASTConstruction
    def bracket(receiver, argument)
      MegaAST::BracketOperator.new(receiver, argument)
    end
  end
  include MegaASTConstruction

  # root = .
  def _root
    get_byte or set_failed_rule :_root
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
  # :startdoc:
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

end
