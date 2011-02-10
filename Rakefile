require 'rake/testtask'

$:.unshift "lib"

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
