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
#  s.description = %q{TODO: Write a gem description}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_development_dependency "rake"
end
