##
# Kpeg plugin for hoe.
#
# === Tasks Provided:
#
# parser            :: Generate parsers for all .kpeg files in your manifest
# .kpeg -> .rb rule :: Generate a parser using kpeg.
#
# NOTE: This plugin is derived from the Hoe::Racc and used under the MIT
# license:
#
# Copyright (c) Ryan Davis, seattle.rb
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module Hoe::Kpeg

  ##
  # Optional: Defines what tasks need to generate parsers first.
  #
  # Defaults to [:multi, :test, :check_manifest]
  #
  # If you have extra tasks that require your parser to be built, add their
  # names here in your hoe spec. eg:
  #
  #    kpeg_tasks << :debug

  attr_accessor :kpeg_tasks

  ##
  # Optional: Defines what flags to use for kpeg. default: "-s -v"

  attr_accessor :kpeg_flags

  ##
  # Initialize variables for kpeg plugin.

  def initialize_kpeg
    self.kpeg_tasks = [:multi, :test, :check_manifest]

    # -v = verbose
    # -s = parser does not require runtime
    self.kpeg_flags ||= "-s -v"

    dependency 'kpeg', '~> 0.9', :development
  end

  ##
  # Define tasks for kpeg plugin

  def define_kpeg_tasks
    kpeg_files   = self.spec.files.find_all { |f| f =~ /\.kpeg$/ }

    parser_files = kpeg_files.map { |f| f.sub(/\.kpeg$/, ".rb") }

    self.clean_globs += parser_files

    rule ".rb" => ".kpeg" do |t|
      kpeg = Gem.bin_path "kpeg", "kpeg"

      begin
        ruby "-rubygems #{kpeg} #{kpeg_flags} -o #{t.name} #{t.source}"
      rescue
        abort "need kpeg, please run rake check_extra_deps"
      end
    end

    desc "build the parser" unless parser_files.empty?
    task :parser

    task :parser => parser_files

    kpeg_tasks.each do |t|
      task t => :parser
    end
  end
end
