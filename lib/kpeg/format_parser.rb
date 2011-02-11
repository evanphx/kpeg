require 'kpeg'
require 'kpeg/compiled_parser'
require 'kpeg/format.kpeg.rb'

module KPeg
  class FormatParser
    def initialize(str, debug=false)
      super
      @g = Grammar.new
    end

    attr_reader :g
    alias_method :grammar, :g
  end
end

