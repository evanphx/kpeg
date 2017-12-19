# -*- encoding: utf-8 -*-
# stub: kpeg 1.0.0.20140103162640 ruby lib

Gem::Specification.new do |s|
  s.name = "kpeg"
  s.version = "1.0.0.20140103162640"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Evan Phoenix"]
  s.date = "2014-01-04"
  s.description = "KPeg is a simple PEG library for Ruby. It provides an API as well as native\ngrammar to build the grammar.\n\nKPeg strives to provide a simple, powerful API without being too exotic.\n\nKPeg supports direct left recursion of rules via the\n{OMeta memoization}[http://www.vpri.org/pdf/tr2008003_experimenting.pdf] trick."
  s.email = ["evan@fallingsnow.net"]
  s.executables = ["kpeg"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.rdoc", "examples/phone_number/README.md", "examples/upper/README.md"]
  s.files = [".autotest", ".travis.yml", "History.txt", "LICENSE", "Manifest.txt", "README.rdoc", "Rakefile", "bin/kpeg", "examples/calculator/calculator.kpeg", "examples/calculator/calculator.rb", "examples/foreign_reference/literals.kpeg", "examples/foreign_reference/matcher.kpeg", "examples/foreign_reference/matcher.rb", "examples/lua_string/driver.rb", "examples/lua_string/lua_string.kpeg", "examples/lua_string/lua_string.kpeg.rb", "examples/phone_number/README.md", "examples/phone_number/phone_number.kpeg", "examples/phone_number/phone_number.rb", "examples/upper/README.md", "examples/upper/upper.kpeg", "examples/upper/upper.rb", "kpeg.gemspec", "lib/hoe/kpeg.rb", "lib/kpeg.rb", "lib/kpeg/code_generator.rb", "lib/kpeg/compiled_parser.rb", "lib/kpeg/format_parser.kpeg", "lib/kpeg/format_parser.rb", "lib/kpeg/grammar.rb", "lib/kpeg/grammar_renderer.rb", "lib/kpeg/match.rb", "lib/kpeg/parser.rb", "lib/kpeg/position.rb", "lib/kpeg/string_escape.kpeg", "lib/kpeg/string_escape.rb", "test/inputs/comments.kpeg", "test/test_kpeg.rb", "test/test_kpeg_code_generator.rb", "test/test_kpeg_compiled_parser.rb", "test/test_kpeg_format.rb", "test/test_kpeg_format_parser_round_trip.rb", "test/test_kpeg_grammar.rb", "test/test_kpeg_grammar_renderer.rb", "vim/syntax_kpeg/ftdetect/kpeg.vim", "vim/syntax_kpeg/syntax/kpeg.vim", "test/test_kpeg_string_escape.rb", ".gemtest"]
  s.homepage = "https://github.com/evanphx/kpeg"
  s.licenses = ["BSD-3-Clause"]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "kpeg"
  s.rubygems_version = "2.1.10"
  s.summary = "KPeg is a simple PEG library for Ruby"
  s.test_files = ["test/test_kpeg.rb", "test/test_kpeg_code_generator.rb", "test/test_kpeg_compiled_parser.rb", "test/test_kpeg_format.rb", "test/test_kpeg_format_parser_round_trip.rb", "test/test_kpeg_grammar.rb", "test/test_kpeg_grammar_renderer.rb", "test/test_kpeg_string_escape.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<minitest>, ["~> 5.2"])
      s.add_development_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_development_dependency(%q<hoe>, ["~> 3.7"])
    else
      s.add_dependency(%q<minitest>, ["~> 5.2"])
      s.add_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_dependency(%q<hoe>, ["~> 3.7"])
    end
  else
    s.add_dependency(%q<minitest>, ["~> 5.2"])
    s.add_dependency(%q<rdoc>, ["~> 4.0"])
    s.add_dependency(%q<hoe>, ["~> 3.7"])
  end
end
