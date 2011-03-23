# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "kpeg/version"

Gem::Specification.new do |s|
  s.name        = "kpeg"
  s.version     = KPeg::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Evan Phoenix"]
  s.email       = ["evan@fallingsnow.net"]
  s.homepage    = "https://github.com/evanphx/kpeg"
  s.summary     = %q{Peg-based Code Generator}
  s.description = %q{A tool for generating parsers using PEG}

  rb = Dir["lib/**/*.rb"] << "bin/kpeg"
  docs = Dir["doc/**/*"]

  s.files = rb + docs + ["LICENSE", "README.md", "Rakefile", "kpeg.gemspec", "Gemfile"]
  s.test_files    = Dir["test/**/*.rb"]
  s.bindir = "bin"
  s.executables = ["kpeg"]
  s.require_paths = ["lib"]
  s.add_development_dependency "rake"
end
