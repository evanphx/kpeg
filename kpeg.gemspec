# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "kpeg"
  s.version = "0.8.5.20120306163408"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Eric Hodel"]
  s.cert_chain = ["/Users/drbrain/.gem/gem-public_cert.pem"]
  s.date = "2012-03-07"
  s.description = "KPeg is a simple PEG library for Ruby. It provides an API as well as native\ngrammar to build the grammar.\n\nKPeg strives to provide a simple, powerful API without being too exotic.\n\nKPeg supports direct left recursion of rules via the\n{OMeta memoization}[http://www.vpri.org/pdf/tr2008003_experimenting.pdf] trick."
  s.email = ["drbrain@segment7.net"]
  s.executables = ["kpeg"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.rdoc"]
  s.files = [".autotest", "Gemfile", "Gemfile.lock", "History.txt", "LICENSE", "Manifest.txt", "README.rdoc", "Rakefile", "bin/kpeg", "examples/calculator/calculator.kpeg", "examples/calculator/calculator.rb", "examples/foreign_reference/literals.kpeg", "examples/foreign_reference/matcher.kpeg", "examples/foreign_reference/matcher.rb", "examples/lua_string/driver.rb", "examples/lua_string/lua_string.kpeg", "examples/lua_string/lua_string.kpeg.rb", "examples/phone_number/README.md", "examples/phone_number/phone_number.kpeg", "examples/phone_number/phone_number.rb", "examples/upper/README.md", "examples/upper/upper.kpeg", "examples/upper/upper.rb", "kpeg.gemspec", "lib/kpeg.rb", "lib/kpeg/code_generator.rb", "lib/kpeg/compiled_parser.rb", "lib/kpeg/format.kpeg", "lib/kpeg/format_parser.rb", "lib/kpeg/grammar.rb", "lib/kpeg/grammar_renderer.rb", "lib/kpeg/match.rb", "lib/kpeg/parser.rb", "lib/kpeg/position.rb", "lib/kpeg/string_escape.kpeg", "lib/kpeg/string_escape.rb", "lib/kpeg/version.rb", "test/inputs/comments.kpeg", "test/test_file_parser_roundtrip.rb", "test/test_gen_calc.rb", "test/test_kpeg.rb", "test/test_kpeg_code_generator.rb", "test/test_kpeg_compiled_parser.rb", "test/test_kpeg_format.rb", "test/test_kpeg_grammar_renderer.rb", "test/test_left_recursion.rb", "vim/syntax_kpeg/ftdetect/kpeg.vim", "vim/syntax_kpeg/syntax/kpeg.vim", ".gemtest"]
  s.homepage = "https://github.com/evanphx/kpeg"
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "kpeg"
  s.rubygems_version = "1.8.12"
  s.signing_key = "/Users/drbrain/.gem/gem-private_key.pem"
  s.summary = "KPeg is a simple PEG library for Ruby"
  s.test_files = ["test/test_file_parser_roundtrip.rb", "test/test_gen_calc.rb", "test/test_kpeg.rb", "test/test_kpeg_code_generator.rb", "test/test_kpeg_compiled_parser.rb", "test/test_kpeg_format.rb", "test/test_kpeg_grammar_renderer.rb", "test/test_left_recursion.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<minitest>, ["~> 2.11"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.10"])
      s.add_development_dependency(%q<hoe>, ["~> 2.15"])
    else
      s.add_dependency(%q<minitest>, ["~> 2.11"])
      s.add_dependency(%q<rdoc>, ["~> 3.10"])
      s.add_dependency(%q<hoe>, ["~> 2.15"])
    end
  else
    s.add_dependency(%q<minitest>, ["~> 2.11"])
    s.add_dependency(%q<rdoc>, ["~> 3.10"])
    s.add_dependency(%q<hoe>, ["~> 2.15"])
  end
end
