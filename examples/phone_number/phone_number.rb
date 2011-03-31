require 'rubygems'
require "phone_number.kpeg"

parser = PhoneNumber.new("aaaa")
puts parser.parse
