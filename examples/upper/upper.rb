# Make sure you have the kpeg gem installed
require 'rubygems'
# To generate the upper.kpeg file run kpeg upper.kpeg
require "upper.kpeg" # Require the generated parser

## Accepted Strings
# a lower case string. Another lower case string.
# A LOWER CASE STRING. ANOTHER LOWER CASE STRING.
# a  string     with   lots  of    spaces.

## Not accepted strings (there are tons)
# Anything that doesn't stick to spaces and periods, very brittle but it is a simple example

parser = Upper.new("a lower case string. Another lower case string.")
if parser.parse
  puts parser.output
end