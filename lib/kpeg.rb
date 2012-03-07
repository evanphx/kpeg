module KPeg

  VERSION = "0.8.5"

  def self.grammar
    g = Grammar.new
    yield g
    g
  end

  def self.match(str, gram)
    scan = Parser.new(str, gram)
    scan.parse
  end

  def self.load_grammar(file, log=false)
    parser = KPeg::FormatParser.new File.read(file)
    if !parser.parse
      parser.raise_error
    end

    return parser.grammar
  end

  def self.load(file, name)
    grammar = load_grammar(file)
    cg = KPeg::CodeGenerator.new name, grammar

    code = cg.output

    warn "[Loading parser '#{name}' => #{code.size} bytes]"

    Object.module_eval code
    true
  end

  def self.compile(str, name, scope=Object)
    parser = KPeg::FormatParser.new str
    unless parser.parse
      parser.raise_error
    end

    cg = KPeg::CodeGenerator.new name, parser.grammar

    code = cg.output

    scope.module_eval code
    true
  end
end

require 'kpeg/grammar'
require 'kpeg/format_parser'
require 'kpeg/code_generator'

