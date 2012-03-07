# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :bundler
Hoe.plugin :gemspec
Hoe.plugin :git
Hoe.plugin :minitest
Hoe.plugin :travis

Hoe.spec 'kpeg' do
  developer 'Eric Hodel', 'drbrain@segment7.net'
end

task :grammar do
  require 'kpeg'
  require 'kpeg/format'
  require 'kpeg/grammar_renderer'

  gr = KPeg::GrammarRenderer.new(KPeg::FORMAT)
  gr.render(STDOUT)
end

desc "build the parser"
task :parser do
  ruby "-Ilib bin/kpeg -o lib/kpeg/string_escape.rb -f lib/kpeg/string_escape.kpeg"
  ruby "-Ilib bin/kpeg -o lib/kpeg/format_parser.rb -s -f lib/kpeg/format.kpeg"
end

# vim: syntax=ruby
