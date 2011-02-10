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
    parser = Parser.new(File.read(file), FORMAT, log)
    m = parser.parse

    if parser.failed?
      raise "Parse failure"
    end

    gram = Grammar.new
    m.value(gram)

    return gram
  end

end
