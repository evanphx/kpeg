require 'kpeg'
require 'kpeg/compiled_parser'
require 'kpeg/format.kpeg.rb'

module KPeg
  class FormatParser
    def initialize(str)
      super
      @g = Grammar.new
    end

    attr_reader :g
  end
end

