require 'test/unit'
require 'kpeg'
require 'kpeg/format'
require 'kpeg/code_generator'
require 'stringio'

class TestKPegCodeGenerator < Test::Unit::TestCase
  GRAMMAR = <<-'STR'
Stmt    = - Expr:e EOL                  { @answers << e }
        | ( !EOL . )* EOL               { puts "error" }

Expr    = ID:i ASSIGN Sum:s             { @vars[i] = s }
        | Sum:s                         { s }

Sum     = Product:l
                ( PLUS  Product:r       { l += r }
                | MINUS Product:r       { l -= r }
                )*                      { l }

Product = Value:l
                ( TIMES  Value:r        { l *= r }
                | DIVIDE Value:r        { l /= r }
                )*                      { l }

Value   = NUMBER:i                      { i }
        | ID:i !ASSIGN                  { @vars[i] }
        | OPEN Expr:i CLOSE             { i }

NUMBER  = < [0-9]+ >    -               { text.to_i }
ID      = < [a-z] >     -               { text }
ASSIGN  = '='           -
PLUS    = '+'           -
MINUS   = '-'           -
TIMES   = '*'           -
DIVIDE  = '/'           -
OPEN    = '('           -
CLOSE   = ')'           -

-       = (' ' | '\t')*
EOL     = ('\n' | '\r\n' | '\r' | ';') -

root    = Stmt+
  STR

  def test_parse
    parc = KPeg::Parser.new(GRAMMAR, KPeg::FORMAT)
    m = parc.parse

    assert !parc.failed?, "Unable to parse"

    gram = KPeg::Grammar.new
    m.value(gram)

    # gr = KPeg::GrammarRenderer.new(gram)
    # puts
    # gr.render(STDOUT)

    cg = KPeg::CodeGenerator.new "TestCalc", gram

    code = cg.make("i = 3+4; j = i*8; i + j * 2;")
    code.instance_variable_set(:@vars, {})
    code.instance_variable_set(:@answers, [])
    assert_equal true, code.parse
    assert_equal [7,56,119], code.instance_variable_get(:@answers)
  end
end
