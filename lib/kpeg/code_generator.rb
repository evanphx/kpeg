require 'kpeg/grammar_renderer'
require 'stringio'

module KPeg
  class CodeGenerator
    def initialize(name, gram, debug=false)
      @name = name
      @grammar = gram
      @debug = debug
      @saves = 0
      @output = nil
      @standalone = false
    end

    attr_accessor :standalone

    def method_name(name)
      name = name.gsub("-","_hyphen_")
      "_#{name}"
    end

    def save
      if @saves == 0
        str = "_save"
      else
        str = "_save#{@saves}"
      end

      @saves += 1
      str
    end

    def reset_saves
      @saves = 0
    end

    def output_ast(short, code, description)
      parser = FormatParser.new description

      # just skip it if it's bad.
      return unless parser.parse "ast_root"

      name, attrs = parser.result

      code << "    class #{name} < Node\n"
      code << "      def initialize(#{attrs.join(', ')})\n"
      attrs.each do |at|
        code << "        @#{at} = #{at}\n"
      end
      code << "      end\n"
      attrs.each do |at|
        code << "      attr_reader :#{at}\n"
      end
      code << "    end\n"

      [short, name, attrs]
    end

    def handle_ast(code)
      output_node = false

      root = @grammar.variables["ast-location"] || "AST"

      methods = []

      vars = @grammar.variables.keys.sort

      vars.each do |name|
        val = @grammar.variables[name]

        if val.index("ast ") == 0
          unless output_node
            code << "\n"
            code << "  module #{root}\n"
            code << "    class Node; end\n"
            output_node = true
          end
          if m = output_ast(name, code, val[4..-1])
            methods << m
          end
        end
      end

      if output_node
        code << "  end\n"
        code << "  module #{root}Construction\n"
        methods.each do |short, name, attrs|
          code << "    def #{short}(#{attrs.join(', ')})\n"
          code << "      #{root}::#{name}.new(#{attrs.join(', ')})\n"
          code << "    end\n"
        end
        code << "  end\n"
        code << "  include #{root}Construction\n"
      end
    end

    def indentify(code, indent)
      "#{"  " * indent}#{code}"
    end

    # Default indent is 4 spaces (indent=2)
    def output_op(code, op, indent=2)
      case op
      when Dot
        code << indentify("_tmp = get_byte\n", indent)
      when LiteralString
        code << indentify("_tmp = match_string(#{op.string.dump})\n", indent)
      when LiteralRegexp
        if op.regexp.respond_to?(:kcode)
          lang = op.regexp.kcode.to_s[0,1]
        else
          # Let default ruby string handling figure it out
          lang = ""
        end
        code << indentify("_tmp = scan(/\\A#{op.regexp}/#{lang})\n", indent)
      when CharRange
        ss = save()
        if op.start.bytesize == 1 and op.fin.bytesize == 1
          code << indentify("#{ss} = self.pos\n", indent)
          code << indentify("_tmp = get_byte\n", indent)
          code << indentify("if _tmp\n", indent)

          if op.start.respond_to? :getbyte
            left  = op.start.getbyte 0
            right = op.fin.getbyte 0
          else
            left  = op.start[0]
            right = op.fin[0]
          end

          code << indentify("  unless _tmp >= #{left} and _tmp <= #{right}\n", indent)
          code << indentify("    self.pos = #{ss}\n", indent)
          code << indentify("    _tmp = nil\n", indent)
          code << indentify("  end\n", indent)
          code << indentify("end\n", indent)
        else
          raise "Unsupported char range - #{op.inspect}"
        end
      when Choice
        ss = save()
        code << "\n"
        code << indentify("#{ss} = self.pos\n", indent)
        code << indentify("while true # choice\n", indent)
        op.ops.each_with_index do |n,idx|
          output_op code, n, (indent+1)

          code << indentify("  break if _tmp\n", indent)
          code << indentify("  self.pos = #{ss}\n", indent)
          if idx == op.ops.size - 1
            code << indentify("  break\n", indent)
          end
        end
        code << indentify("end # end choice\n\n", indent)
      when Multiple
        ss = save()
        if op.min == 0 and op.max == 1
          code << indentify("#{ss} = self.pos\n", indent)
          output_op code, op.op, indent
          if op.save_values
            code << indentify("@result = nil unless _tmp\n", indent)
          end
          code << indentify("unless _tmp\n", indent)
          code << indentify("  _tmp = true\n", indent)
          code << indentify("  self.pos = #{ss}\n", indent)
          code << indentify("end\n", indent)
        elsif op.min == 0 and !op.max
          if op.save_values
            code << indentify("_ary = []\n", indent)
          end

          code << indentify("while true\n", indent)
          output_op code, op.op, (indent+1)
          if op.save_values
            code << indentify("  _ary << @result if _tmp\n", indent)
          end
          code << indentify("  break unless _tmp\n", indent)
          code << indentify("end\n", indent)
          code << indentify("_tmp = true\n", indent)

          if op.save_values
            code << indentify("@result = _ary\n", indent)
          end

        elsif op.min == 1 and !op.max
          code << indentify("#{ss} = self.pos\n", indent)
          if op.save_values
            code << indentify("_ary = []\n", indent)
          end
          output_op code, op.op, indent
          code << indentify("if _tmp\n", indent)
          if op.save_values
            code << indentify("  _ary << @result\n", indent)
          end
          code << indentify("  while true\n", indent)
          output_op code, op.op, (indent+2)
          if op.save_values
            code << indentify("    _ary << @result if _tmp\n", indent)
          end
          code << indentify("    break unless _tmp\n", indent)
          code << indentify("  end\n", indent)
          code << indentify("  _tmp = true\n", indent)
          if op.save_values
            code << indentify("  @result = _ary\n", indent)
          end
          code << indentify("else\n", indent)
          code << indentify("  self.pos = #{ss}\n", indent)
          code << indentify("end\n", indent)
        else
          code << indentify("#{ss} = self.pos\n", indent)
          code << indentify("_count = 0\n", indent)
          code << indentify("while true\n", indent)
          output_op code, op.op, (indent+1)
          code << indentify("  if _tmp\n", indent)
          code << indentify("    _count += 1\n", indent)
          code << indentify("    break if _count == #{op.max}\n", indent)
          code << indentify("  else\n", indent)
          code << indentify("    break\n", indent)
          code << indentify("  end\n", indent)
          code << indentify("end\n", indent)
          code << indentify("if _count >= #{op.min}\n", indent)
          code << indentify("  _tmp = true\n", indent)
          code << indentify("else\n", indent)
          code << indentify("  self.pos = #{ss}\n", indent)
          code << indentify("  _tmp = nil\n", indent)
          code << indentify("end\n", indent)
        end

      when Sequence
        ss = save()
        code << "\n"
        code << indentify("#{ss} = self.pos\n", indent)
        code << indentify("while true # sequence\n", indent)
        op.ops.each_with_index do |n, idx|
          output_op code, n, (indent+1)

          if idx == op.ops.size - 1
            code << indentify("  unless _tmp\n", indent)
            code << indentify("    self.pos = #{ss}\n", indent)
            code << indentify("  end\n", indent)
            code << indentify("  break\n", indent)
          else
            code << indentify("  unless _tmp\n", indent)
            code << indentify("    self.pos = #{ss}\n", indent)
            code << indentify("    break\n", indent)
            code << indentify("  end\n", indent)
          end
        end
        code << indentify("end # end sequence\n\n", indent)
      when AndPredicate
        ss = save()
        code << indentify("#{ss} = self.pos\n", indent)
        if op.op.kind_of? Action
          code << indentify("_tmp = begin; #{op.op.action}; end\n", indent)
        else
          output_op code, op.op, indent
        end
        code << indentify("self.pos = #{ss}\n", indent)
      when NotPredicate
        ss = save()
        code << indentify("#{ss} = self.pos\n", indent)
        if op.op.kind_of? Action
          code << indentify("_tmp = begin; #{op.op.action}; end\n", indent)
        else
          output_op code, op.op, indent
        end
        code << indentify("_tmp = _tmp ? nil : true\n", indent)
        code << indentify("self.pos = #{ss}\n", indent)
      when RuleReference
        if op.arguments
          code << indentify("_tmp = apply_with_args(:#{method_name op.rule_name}, #{op.arguments[1..-2]})\n", indent)
        else
          code << indentify("_tmp = apply(:#{method_name op.rule_name})\n", indent)
        end
      when InvokeRule
        if op.arguments
          code << indentify("_tmp = #{method_name op.rule_name}#{op.arguments}\n", indent)
        else
          code << indentify("_tmp = #{method_name op.rule_name}()\n", indent)
        end
      when ForeignInvokeRule
        if op.arguments
          code << indentify("_tmp = @_grammar_#{op.grammar_name}.external_invoke(self, :#{method_name op.rule_name}, #{op.arguments[1..-2]})\n", indent)
        else
          code << indentify("_tmp = @_grammar_#{op.grammar_name}.external_invoke(self, :#{method_name op.rule_name})\n", indent)
        end
      when Tag
        if op.tag_name and !op.tag_name.empty?
          output_op code, op.op, indent
          code << indentify("#{op.tag_name} = @result\n", indent)
        else
          output_op code, op.op, indent
        end
      when Action
        code << indentify("@result = begin; ", indent)
        code << op.action << "; end\n"
        if @debug
          code << indentify("puts \"   => \" #{op.action.dump} \" => \#{@result.inspect} \\n\"\n", indent)
        end
        code << indentify("_tmp = true\n", indent)
      when Collect
        code << indentify("_text_start = self.pos\n", indent)
        output_op code, op.op, indent
        code << indentify("if _tmp\n", indent)
        code << indentify("  text = get_text(_text_start)\n", indent)
        code << indentify("end\n", indent)
      when Bounds
        code << indentify("_bounds_start = self.pos\n", indent)
        output_op code, op.op, indent
        code << indentify("if _tmp\n", indent)
        code << indentify("  bounds = [_bounds_start, self.pos]\n", indent)
        code << indentify("end\n", indent)
      else
        raise "Unknown op - #{op.class}"
      end
    end

    def standalone_region(path, marker = "STANDALONE")
      expanded_path = File.expand_path("../#{path}", __FILE__)
      cp = File.read(expanded_path)

      start_marker = "# #{marker} START"
      end_marker   = /^\s*# #{Regexp.escape marker} END/

      start = cp.index(start_marker) + start_marker.length + 1 # \n
      fin   = cp.index(end_marker)

      unless start and fin
        abort("#{marker} boundaries in #{path} missing " \
              "for standalone generation")
      end

      cp[start..fin]
    end

    def output
      return @output if @output

      code = []

      output_header(code)
      output_grammar(code)
      output_footer(code)

      @output = code.join
    end

    ##
    # Output of class end and footer

    def output_footer(code)
      code << "end\n"

      if footer = @grammar.directives['footer']
        code << footer.action
      end
    end

    ##
    # Output of grammar and rules

    def output_grammar(code)
      code << "  # :stopdoc:\n"
      handle_ast(code)

      fg = @grammar.foreign_grammars

      if fg.empty?
        if @standalone
          code << "  def setup_foreign_grammar; end\n"
        end
      else
        code << "  def setup_foreign_grammar\n"
        @grammar.foreign_grammars.each do |name, gram|
          code << "    @_grammar_#{name} = #{gram}.new(nil)\n"
        end
        code << "  end\n"
      end

      render = GrammarRenderer.new(@grammar)

      renderings = {}

      @grammar.rule_order.each do |name|
        reset_saves

        rule = @grammar.rules[name]
        io = StringIO.new
        render.render_op io, rule.op

        rend = io.string
        rend.gsub! "\n", " "

        renderings[name] = rend

        code << "\n"
        code << "  # #{name} = #{rend}\n"

        if rule.arguments
          code << "  def #{method_name name}(#{rule.arguments.join(',')})\n"
        else
          code << "  def #{method_name name}\n"
        end

        if @debug
          code << "    puts \"START #{name} @ \#{show_pos}\\n\"\n"
        end

        output_op code, rule.op
        if @debug
          code << "    if _tmp\n"
          code << "      puts \"   OK #{name} @ \#{show_pos}\\n\"\n"
          code << "    else\n"
          code << "      puts \" FAIL #{name} @ \#{show_pos}\\n\"\n"
          code << "    end\n"
        end

        code << "    set_failed_rule :#{method_name name} unless _tmp\n"
        code << "    return _tmp\n"
        code << "  end\n"
      end

      code << "\n  Rules = {}\n"
      @grammar.rule_order.each do |name|
        rend = GrammarRenderer.escape renderings[name], true
        code << "  Rules[:#{method_name name}] = rule_info(\"#{name}\", \"#{rend}\")\n"
      end

      code << "  # :startdoc:\n"
    end

    ##
    # Output up to the user-defined setup actions

    def output_header(code)
      if header = @grammar.directives['header']
        code << header.action.strip
        code << "\n"
      end

      pre_class = @grammar.directives['pre-class']

      if @standalone
        if pre_class
          code << pre_class.action.strip
          code << "\n"
        end
        code << "class #{@name}\n"

        cp  = standalone_region("compiled_parser.rb")
        cpi = standalone_region("compiled_parser.rb", "INITIALIZE")
        pp  = standalone_region("position.rb")

        cp.gsub!(/include Position/, pp)
        code << "  # :stopdoc:\n"
        code << cpi << "\n" unless @grammar.variables['custom_initialize']
        code << cp  << "\n"
        code << "  # :startdoc:\n"
      else
        code << "require 'kpeg/compiled_parser'\n\n"
        if pre_class
          code << pre_class.action.strip
          code << "\n"
        end
        code << "class #{@name} < KPeg::CompiledParser\n"
      end

      @grammar.setup_actions.each do |act|
        code << "\n#{act.action}\n\n"
      end
    end

    def make(str)
      m = Module.new
      m.module_eval output, "(kpeg parser #{@name})"

      cls = m.const_get(@name)
      cls.new(str)
    end

    def parse(str)
      make(str).parse
    end
  end
end
