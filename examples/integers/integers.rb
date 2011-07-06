$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('..', __FILE__)

require 'integers.kpeg.rb'

def parse(str)
  parser = IntegerParser.new(str)
  if parser.parse
    print "=> ", parser.result, "\n"
  else
    parser.show_error
  end
end

if ARGV.empty?
  puts "This program parses hexadecimal, octal, binary, decimal literals"
  puts "underscore is allowed between digits."
  puts "---"
  puts "Example inputs:"
  examples = %W( 10 0x10 0b10 0b1_0 0o10 010 +10_000 -0xCAFE_BABE )
  examples.map { |a| print "<< ", a, "\n"; parse(a) }
  puts "--"


  print IntegerParser,": "
  line = nil
  parse(line.chomp) or print(IntegerParser, ": ") while line = gets
else
  ARGV.map { |a| print "<< ", a, "\n"; parse(a) }
end
