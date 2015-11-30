module TinyMarkdown; end
require_relative 'tiny_markdown.kpeg.rb'
require_relative 'node.rb'

md = File.read(ARGV[0])

parser = TinyMarkdown::Parser.new(md)
parser.parse
ast = parser.ast
puts ast.to_html
