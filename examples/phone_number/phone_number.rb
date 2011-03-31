require 'rubygems'
require "phone_number.kpeg.rb"

parser = PhoneNumber.new("8888888888")
puts parser.parse
puts parser.phone_number
