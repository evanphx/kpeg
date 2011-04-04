require 'rubygems'
require './matcher.kpeg.rb'

parser = Matcher.new("this is a string.")
puts parser.parse