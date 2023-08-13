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
        code << indentify("get_byte", indent)
      when LiteralString
        code << indentify("match_string(#{op.string.dump})", indent)
      when LiteralRegexp
        if op.regexp.respond_to?(:kcode)
          lang = op.regexp.kcode.to_s[0,1]
        else
          # Let default ruby string handling figure it out
          lang = ""
        end
        code << indentify("scan(/\\G#{op.regexp}/#{lang})", indent)
      when CharRange
        if op.start.bytesize == 1 and op.fin.bytesize == 1
          code << indentify("sequence(self.pos, (  # char range\n", indent)
          code << indentify("  _tmp = get_byte\n", indent)

          if op.start.respond_to? :getbyte
            left  = op.start.getbyte 0
            right = op.fin.getbyte 0
          else
            left  = op.start[0]
            right = op.fin[0]
          end

          code << indentify("  _tmp && _tmp >= #{left} && _tmp <= #{right}\n", indent)
          code << indentify("))", indent)
        else
          raise "Unsupported char range - #{op.inspect}"
        end
      when Choice
        code << indentify("( # choice\n", indent)
        op.ops.each_with_index do |n,idx|
          if idx > 0
            code << " ||\n"
          end
          output_op code, n, indent+1
        end
        code << "\n"
        code << indentify("  # end choice\n", indent)
        code << indentify(")", indent)
      when Multiple
        if op.min == 0 && op.max == 1
          code << indentify("(  # optional\n", indent)
          output_op code, op.op, indent+1
          code << " ||\n"
          if op.save_values
            code << indentify("  ( @result = nil; true )  # end optional\n", indent)
          else
            code << indentify("  true  # end optional\n", indent)
          end
          code << indentify(")", indent)
        elsif op.min == 0 && !op.max && !op.save_values
          code << indentify("while true  # kleene\n", indent)
          output_op code, op.op, indent+1
          code << " || (break true) # end kleene\n"
          code << indentify("end", indent)
        else
          code << indentify("loop_range(#{op.min}..#{op.max}, #{op.save_values ? true : false}) {\n", indent)
          output_op code, op.op, indent+1
          code << "\n" << indentify("}", indent)
        end
      when Sequence
        code << indentify("sequence(self.pos,  # sequence\n", indent)
        op.ops.each_with_index do |n, idx|
          if idx > 0
            code << " &&\n"
          end
          output_op code, n, indent+1
        end
        code << "  # end sequence\n"
        code << indentify(")", indent)
      when AndPredicate
        code << indentify("look_ahead(self.pos,\n", indent)
        if op.op.kind_of? Action
          code << indentify(op.op.action.strip, indent+1)
        else
          output_op code, op.op, indent+1
        end
        code << "  # end look ahead\n"
        code << indentify(")", indent)
      when NotPredicate
        code << indentify("look_negation(self.pos,\n", indent)
        if op.op.kind_of? Action
          code << indentify(op.op.action.strip, indent+1)
        else
          output_op code, op.op, indent+1
        end
        code << "  # end negation\n"
        code << indentify(")", indent)
      when RuleReference
        if op.arguments
          code << indentify("apply_with_args(:#{method_name op.rule_name}, #{op.arguments[1..-2]})", indent)
        else
          code << indentify("apply(:#{method_name op.rule_name})", indent)
        end
      when InvokeRule
        if op.arguments
          code << indentify("#{method_name op.rule_name}#{op.arguments}", indent)
        else
          code << indentify("#{method_name op.rule_name}()", indent)
        end
      when ForeignInvokeRule
        if op.arguments
          code << indentify("@_grammar_#{op.grammar_name}.external_invoke(self, :#{method_name op.rule_name}, #{op.arguments[1..-2]})", indent)
        else
          code << indentify("@_grammar_#{op.grammar_name}.external_invoke(self, :#{method_name op.rule_name})", indent)
        end
      when Tag
        output_op code, op.op, indent
        if op.tag_name and !op.tag_name.empty?
          code << " &&\n"
          code << indentify("( #{op.tag_name} = @result; true )", indent)
        end
      when Action
        action = op.action.strip
        if action =~ /[\n;]/
          code << indentify("( @result = begin\n", indent)
          code << indentify(action, indent+1)
          code << "\n" << indentify("  end", indent)
        else
          code << indentify("( @result = (#{action})", indent)
        end
        if @debug
          code << indentify("\n", indent)
          code << indentify("puts \"   => \" #{op.action.dump} \" => \#{@result.inspect} \\n\"\n", indent)
          code << indentify("true)", indent)
        else
          code << "; true )"
        end
      when Collect
        code << indentify("( _text_start = self.pos\n", indent)
        output_op code, op.op, indent+1
        code << " &&\n"
        code << indentify("  ( text = get_text(_text_start); true )\n", indent)
        code << indentify(")", indent)
      when Bounds
        code << indentify("( _bounds_start = self.pos\n", indent)
        output_op code, op.op, indent+1
        code << " &&\n"
        code << indentify("  (bounds = [_bounds_start, self.pos]; true )\n", indent)
        code << indentify(")", indent)
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

        if @debug
          code << "    _tmp = begin\n"
          output_op code, rule.op, 3
          code << "\n"
          code << "    end or set_failed_rule :#{method_name name}\n"
          code << "    st= _tmp ? '  OK' : 'FAIL'\n"
          code << "    puts \" \#{st} #{name} @ \#{show_pos}\\n\"\n"
          code << "    _tmp\n"
        else
          output_op code, rule.op
          code << " or set_failed_rule :#{method_name name}\n"
        end
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

        cp.gsub!(/^\s*include Position/, pp)
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
