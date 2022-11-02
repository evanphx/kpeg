# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "kpeg"
  s.version = "1.3.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/evanphx/kpeg/issues", "homepage_uri" => "https://github.com/evanphx/kpeg" } if s.respond_to? :metadata=
  s.require_paths = ["lib"]
  s.authors = ["Evan Phoenix"]
  s.date = "2022-11-02"
  s.description = "KPeg is a simple PEG library for Ruby. It provides an API as well as native\ngrammar to build the grammar.\n\nKPeg strives to provide a simple, powerful API without being too exotic.\n\nKPeg supports direct left recursion of rules via the\n{OMeta memoization}[http://www.vpri.org/pdf/tr2008003_experimenting.pdf] trick."
  s.email = ["evan@fallingsnow.net"]
  s.executables = ["kpeg"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.rdoc", "examples/phone_number/README.md", "examples/tiny_markdown/sample.md", "examples/upper/README.md"]
  s.files = [".autotest", "Gemfile", "History.txt", "LICENSE", "Manifest.txt", "README.rdoc", "Rakefile", "bin/kpeg", "examples/calculator/calculator.kpeg", "examples/calculator/calculator.rb", "examples/foreign_reference/literals.kpeg", "examples/foreign_reference/matcher.kpeg", "examples/foreign_reference/matcher.rb", "examples/lua_string/driver.rb", "examples/lua_string/lua_string.kpeg", "examples/lua_string/lua_string.kpeg.rb", "examples/phone_number/README.md", "examples/phone_number/phone_number.kpeg", "examples/phone_number/phone_number.rb", "examples/tiny_markdown/Rakefile", "examples/tiny_markdown/driver.rb", "examples/tiny_markdown/node.rb", "examples/tiny_markdown/sample.md", "examples/tiny_markdown/tiny_markdown.kpeg", "examples/tiny_markdown/tiny_markdown.kpeg.rb", "examples/upper/README.md", "examples/upper/upper.kpeg", "examples/upper/upper.rb", "kpeg.gemspec", "lib/hoe/kpeg.rb", "lib/kpeg.rb", "lib/kpeg/code_generator.rb", "lib/kpeg/compiled_parser.rb", "lib/kpeg/format_parser.kpeg", "lib/kpeg/format_parser.rb", "lib/kpeg/grammar.rb", "lib/kpeg/grammar_renderer.rb", "lib/kpeg/match.rb", "lib/kpeg/parser.rb", "lib/kpeg/position.rb", "lib/kpeg/string_escape.kpeg", "lib/kpeg/string_escape.rb", "test/inputs/comments.kpeg", "test/test_kpeg.rb", "test/test_kpeg_code_generator.rb", "test/test_kpeg_compiled_parser.rb", "test/test_kpeg_format.rb", "test/test_kpeg_format_parser_round_trip.rb", "test/test_kpeg_grammar.rb", "test/test_kpeg_grammar_renderer.rb", "test/test_kpeg_string_escape.rb", "vim/syntax_kpeg/ftdetect/kpeg.vim", "vim/syntax_kpeg/syntax/kpeg.vim"]
  s.homepage = "https://github.com/evanphx/kpeg"
  s.licenses = ["BSD-3-Clause"]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.rubygems_version = "3.3.7"
  s.summary = "KPeg is a simple PEG library for Ruby"

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<minitest>, ["~> 5.16"])
    s.add_development_dependency(%q<rdoc>, [">= 4.0", "< 7"])
    s.add_development_dependency(%q<rake>, [">= 0.8", "< 15.0"])
  else
    s.add_dependency(%q<minitest>, ["~> 5.16"])
    s.add_dependency(%q<rdoc>, [">= 4.0", "< 7"])
    s.add_dependency(%q<rake>, [">= 0.8", "< 15.0"])
  end
end
