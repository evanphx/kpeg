require 'rubygems'
require "./phone_number.kpeg.rb"

for number in ["123456789", "1234567890", "(123)4567890", "(123) 456 - 7890",
               "7(123) 456-7890"]
  puts number
  parser = PhoneNumber.new(number)
  puts parser.parse
  puts parser.phone_number
  puts "---"
end
