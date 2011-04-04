require 'rubygems'
require "./calculator.kpeg"

parser = Calculator.new("1 + 2 * 3")
if parser.parse
  puts parser.result
end