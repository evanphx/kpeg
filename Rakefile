require 'rake/testtask'
require 'rubygems/package_task'

$:.unshift "lib"

spec = Gem::Specification.load 'kpeg.gemspec'
Gem::PackageTask.new spec do |t|
  t.need_tar = false
  t.need_zip = false
end

task :default => :test

desc "Run tests"
Rake::TestTask.new do |t|
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end

task :grammar do
  require 'kpeg'
  require 'kpeg/format'
  require 'kpeg/grammar_renderer'

  gr = KPeg::GrammarRenderer.new(KPeg::FORMAT)
  gr.render(STDOUT)
end

desc "rebuild parser"
task :parser do
  sh "ruby -Ilib bin/kpeg -o lib/kpeg/string_escape.rb -f lib/kpeg/string_escape.kpeg"
  sh "ruby -Ilib bin/kpeg -o lib/kpeg/format_parser.rb -s -f lib/kpeg/format.kpeg"
end
