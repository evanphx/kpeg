require 'rubygems'
require "phone_number.kpeg.rb"

parser = PhoneNumber.new("aaaa")
puts parser.parse
