# encoding: utf-8
require 'minitest/autorun'
require 'kpeg'
require 'kpeg/code_generator'
require 'stringio'

class TestKPegCodeGenerator < MiniTest::Unit::TestCase
  def test_dot
    gram = KPeg.grammar do |g|
      g.root = g.dot
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser

  # root = .
  def _root
    _tmp = get_byte
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
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

  # root = "hello"
  def _root
    _tmp = match_string("hello")
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"")
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

  # root = /[0-9]/
  def _root
    _tmp = scan(/\\A(?-mix:[0-9])/)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "/[0-9]/")
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

  # root = /./
  def _root
    _tmp = scan(/\\A(?-mix:.)/)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "/./")
end
    STR
    else
    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser

  # root = /./u
  def _root
    _tmp = scan(/\\A(?-mix:.)/u)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "/./u")
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

  # root = [a-z]
  def _root
    _save = self.pos
    _tmp = get_byte
    if _tmp
      unless _tmp >= 97 and _tmp <= 122
        self.pos = _save
        _tmp = nil
      end
    end
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "[a-z]")
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

  # root = [a-z] "hello"
  def _root

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = get_byte
      if _tmp
        unless _tmp >= 97 and _tmp <= 122
          self.pos = _save1
          _tmp = nil
        end
      end
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("hello")
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "[a-z] \\\"hello\\\"")
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

  # root = ("hello" | "world")
  def _root

    _save = self.pos
    while true # choice
      _tmp = match_string("hello")
      break if _tmp
      self.pos = _save
      _tmp = match_string("world")
      break if _tmp
      self.pos = _save
      break
    end # end choice

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "(\\\"hello\\\" | \\\"world\\\")")
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

  # root = "hello"?
  def _root
    _save = self.pos
    _tmp = match_string("hello")
    unless _tmp
      _tmp = true
      self.pos = _save
    end
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"?")
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

  # root = "hello"*
  def _root
    while true
      _tmp = match_string("hello")
      break unless _tmp
    end
    _tmp = true
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"*")
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

  # root = "hello"+
  def _root
    _save = self.pos
    _tmp = match_string("hello")
    if _tmp
      while true
        _tmp = match_string("hello")
        break unless _tmp
      end
      _tmp = true
    else
      self.pos = _save
    end
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"+")
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

  # root = "hello"[5, 9]
  def _root
    _save = self.pos
    _count = 0
    while true
      _tmp = match_string("hello")
      if _tmp
        _count += 1
        break if _count == 9
      else
        break
      end
    end
    if _count >= 5
      _tmp = true
    else
      self.pos = _save
      _tmp = nil
    end
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"[5, 9]")
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

  # root = "hello" "world"
  def _root

    _save = self.pos
    while true # sequence
      _tmp = match_string("hello")
      unless _tmp
        self.pos = _save
        break
      end
      _tmp = match_string("world")
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\" \\\"world\\\"")
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

  # root = &"hello"
  def _root
    _save = self.pos
    _tmp = match_string("hello")
    self.pos = _save
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "&\\\"hello\\\"")
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

  # root = &{ !defined? @fail }
  def _root
    _save = self.pos
    _tmp = begin;  !defined? @fail ; end
    self.pos = _save
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "&{ !defined? @fail }")
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

  # root = !"hello"
  def _root
    _save = self.pos
    _tmp = match_string("hello")
    _tmp = _tmp ? nil : true
    self.pos = _save
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "!\\\"hello\\\"")
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

  # root = !{ defined? @fail }
  def _root
    _save = self.pos
    _tmp = begin;  defined? @fail ; end
    _tmp = _tmp ? nil : true
    self.pos = _save
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "!{ defined? @fail }")
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

  # greeting = "hello"
  def _greeting
    _tmp = match_string("hello")
    set_failed_rule :_greeting unless _tmp
    return _tmp
  end

  # root = greeting
  def _root
    _tmp = apply(:_greeting)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_greeting] = rule_info("greeting", "\\\"hello\\\"")
  Rules[:_root] = rule_info("root", "greeting")
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

  # greeting = "hello"
  def _greeting
    _tmp = match_string("hello")
    set_failed_rule :_greeting unless _tmp
    return _tmp
  end

  # root = @greeting
  def _root
    _tmp = _greeting()
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_greeting] = rule_info("greeting", "\\\"hello\\\"")
  Rules[:_root] = rule_info("root", "@greeting")
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

  # greeting = "hello"
  def _greeting(a,b)
    _tmp = match_string("hello")
    set_failed_rule :_greeting unless _tmp
    return _tmp
  end

  # root = @greeting(1,2)
  def _root
    _tmp = _greeting(1,2)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_greeting] = rule_info("greeting", "\\\"hello\\\"")
  Rules[:_root] = rule_info("root", "@greeting(1,2)")
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
  def setup_foreign_grammar
    @_grammar_blah = TestKPegCodeGenerator::TestParser.new(nil)
  end

  # root = %blah.greeting
  def _root
    _tmp = @_grammar_blah.external_invoke(self, :_greeting)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "%blah.greeting")
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
  def setup_foreign_grammar
    @_grammar_blah = TestKPegCodeGenerator::TestParser.new(nil)
  end

  # root = %blah.greeting2(1,2)
  def _root
    _tmp = @_grammar_blah.external_invoke(self, :_greeting2, 1,2)
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "%blah.greeting2(1,2)")
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

  # root = "hello":t
  def _root
    _tmp = match_string("hello")
    t = @result
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\":t")
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

  # root = "hello"
  def _root
    _tmp = match_string("hello")
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "\\\"hello\\\"")
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

  # hello = < "hello" > {text}
  def _hello

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = match_string("hello")
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_hello unless _tmp
    return _tmp
  end

  # root = hello?:lots {lots}
  def _root

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _tmp = apply(:_hello)
      @result = nil unless _tmp
      unless _tmp
        _tmp = true
        self.pos = _save1
      end
      lots = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; lots; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_hello] = rule_info("hello", "< \\\"hello\\\" > {text}")
  Rules[:_root] = rule_info("root", "hello?:lots {lots}")
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    code = cg.make("hello")
    assert code.parse
    assert_equal "hello", code.result

    code = cg.make("")
    assert code.parse
    assert_equal nil, code.result
  end


  def test_tag_multiple
    gram = KPeg.grammar do |g|
      g.hello = g.seq(g.collect("hello"), g.action("text"))
      g.root = g.seq g.t(g.kleene(:hello), "lots"), g.action("lots")
    end

    str = <<-STR
require 'kpeg/compiled_parser'

class Test < KPeg::CompiledParser

  # hello = < "hello" > {text}
  def _hello

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = match_string("hello")
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_hello unless _tmp
    return _tmp
  end

  # root = hello*:lots {lots}
  def _root

    _save = self.pos
    while true # sequence
      _ary = []
      while true
        _tmp = apply(:_hello)
        _ary << @result if _tmp
        break unless _tmp
      end
      _tmp = true
      @result = _ary
      lots = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; lots; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_hello] = rule_info("hello", "< \\\"hello\\\" > {text}")
  Rules[:_root] = rule_info("root", "hello*:lots {lots}")
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

  # hello = < "hello" > {text}
  def _hello

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = match_string("hello")
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; text; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_hello unless _tmp
    return _tmp
  end

  # root = hello+:lots {lots}
  def _root

    _save = self.pos
    while true # sequence
      _save1 = self.pos
      _ary = []
      _tmp = apply(:_hello)
      if _tmp
        _ary << @result
        while true
          _tmp = apply(:_hello)
          _ary << @result if _tmp
          break unless _tmp
        end
        _tmp = true
        @result = _ary
      else
        self.pos = _save1
      end
      lots = @result
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin; lots; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_hello] = rule_info("hello", "< \\\"hello\\\" > {text}")
  Rules[:_root] = rule_info("root", "hello+:lots {lots}")
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

  # root = {3 + 4}
  def _root
    @result = begin; 3 + 4; end
    _tmp = true
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "{3 + 4}")
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

  # root = < "hello" > { text }
  def _root

    _save = self.pos
    while true # sequence
      _text_start = self.pos
      _tmp = match_string("hello")
      if _tmp
        text = get_text(_text_start)
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  text ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "< \\\"hello\\\" > { text }")
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

  # root = @< "hello" > { bounds }
  def _root

    _save = self.pos
    while true # sequence
      _bounds_start = self.pos
      _tmp = match_string("hello")
      if _tmp
        bounds = [_bounds_start, self.pos]
      end
      unless _tmp
        self.pos = _save
        break
      end
      @result = begin;  bounds ; end
      _tmp = true
      unless _tmp
        self.pos = _save
      end
      break
    end # end sequence

    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", "@< \\\"hello\\\" > { bounds }")
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

  # root = .
  def _root
    _tmp = get_byte
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
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

  # root = .
  def _root
    _tmp = get_byte
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
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


  # root = .
  def _root
    _tmp = get_byte
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
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
  def bracket(receiver, argument)
    AST::BracketOperator.new(receiver, argument)
  end
  def simple()
    AST::Simple.new()
  end
  def simple2()
    AST::Simple2.new()
  end

  # root = .
  def _root
    _tmp = get_byte
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
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
  def bracket(receiver, argument)
    MegaAST::BracketOperator.new(receiver, argument)
  end

  # root = .
  def _root
    _tmp = get_byte
    set_failed_rule :_root unless _tmp
    return _tmp
  end

  Rules = {}
  Rules[:_root] = rule_info("root", ".")
end
    STR

    cg = KPeg::CodeGenerator.new "Test", gram

    assert_equal str, cg.output

    assert cg.parse("hello")
  end

end
