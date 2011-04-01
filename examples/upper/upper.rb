# Make sure you have the kpeg gem installed
require 'rubygems'
# To generate the upper.kpeg file run kpeg upper.kpeg
require "upper.kpeg.rb" # Require the generated parser

parser = Upper.new("a lower case string. Another lower case string.")
if parser.parse
  puts parser.output
end