require 'rubygems'
require "calculator.kpeg"

parser = Calculator.new("1 + 2")
if parser.parse
  puts parser.result
end