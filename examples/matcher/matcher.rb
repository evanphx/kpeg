require 'rubygems'
require "matcher.kpeg"

parser = Matcher.new("aaaa")
puts parser.parse
