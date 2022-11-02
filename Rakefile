# -*- ruby -*-

require 'rubygems'

task :test => :parser

task :grammar do
  require 'kpeg'
  require 'kpeg/format'
  require 'kpeg/grammar_renderer'

  gr = KPeg::GrammarRenderer.new(KPeg::FORMAT)
  gr.render(STDOUT)
end

rule ".rb" => ".kpeg" do |t|
  ruby "-Ilib bin/kpeg -s -o #{t.name} -f #{t.source}"
end

PARSER_FILES = %w[
  lib/kpeg/string_escape.rb
  lib/kpeg/format_parser.rb
]

PARSER_FILES.map do |parser_file|
  file parser_file => 'lib/kpeg/compiled_parser.rb'
  file parser_file => 'lib/kpeg/code_generator.rb'
  file parser_file => 'lib/kpeg/position.rb'
  file parser_file => parser_file.sub(/\.rb$/, '.kpeg')
end

desc "build the parser"
task :parser => PARSER_FILES

task :gem do
  sh "gem build"
end

# vim: syntax=ruby
