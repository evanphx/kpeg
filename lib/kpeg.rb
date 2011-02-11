require 'kpeg/grammar'

module KPeg
  def self.grammar
    g = Grammar.new
    yield g
    g
  end

  def self.match(str, gram)
    scan = Parser.new(str, gram)
    scan.parse
  end

  def self.load(file, log=false)
    require 'kpeg/format_parser'
    parser = KPeg::FormatParser.new File.read(file)
    parser.parse

    return parser.grammar
  end
end
