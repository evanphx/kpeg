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

task :parser do
  sh "ruby -Ilib bin/kpeg -o lib/kpeg/format_parser.rb -n KPeg::FormatParser -f lib/kpeg/format.kpeg"
end

def gemspec
  @gemspec ||= eval(File.read('kpeg.gemspec'), binding, 'kpeg.gemspec')
end

ROOT_DIR = File.dirname(__FILE__)
require 'rake/gempackagetask'
desc "Build the gem"
task :package=>:gem
task :gem do
  Dir.chdir(ROOT_DIR) do
    sh "gem build kpeg.gemspec"
  end
end

desc "Install the gem locally"
task :install => :gem do
  Dir.chdir(ROOT_DIR) do
    sh %{gem install --local #{gemspec.file_name}}
  end
end

