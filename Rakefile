# -*- ruby -*-

require 'rubygems'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
end

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

rule ".kpeg.rb" => ".kpeg" do |t|
  ruby "-Ilib bin/kpeg -s -o #{t.name} -f #{t.source}"
end

PARSER_FILES = %w[
  lib/kpeg/string_escape.rb
  lib/kpeg/format_parser.rb
]

PARSER_FILES.each do |parser_file|
  file parser_file => 'lib/kpeg/compiled_parser.rb'
  file parser_file => 'lib/kpeg/code_generator.rb'
  file parser_file => 'lib/kpeg/position.rb'
  file parser_file => parser_file.sub(/\.rb$/, '.kpeg')
end

EXAMPLE_FILES = Dir.glob('examples/*/*.kpeg').map{|f| f + ".rb" }

EXAMPLE_FILES.each do |example_file|
  file example_file => 'lib/kpeg/compiled_parser.rb'
  file example_file => 'lib/kpeg/code_generator.rb'
  file example_file => 'lib/kpeg/position.rb'
  file example_file => example_file.sub(/\.rb$/, '')
end

desc "build the parser"
task :parser => PARSER_FILES

desc "build the examples"
task :examples => EXAMPLE_FILES

task :test => :examples

task :gem do
  sh "gem build"
end

# vim: syntax=ruby
