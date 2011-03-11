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
      @indent = 0
      @code = ''
    end

    def add(str, indent=0)
      @indent -= 2 if indent < 0
      @code << (' ' * @indent) + str
      @indent += 2 if indent > 0 
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

    def output_op(code, op, indent_adjust=0)
      @indent += indent_adjust
      @code = code
      case op
      when Dot
        add "    _tmp = get_byte\n"
      when LiteralString
        add "    _tmp = match_string(#{op.string.dump})\n"
      when LiteralRegexp
        add "    _tmp = scan(/\\A#{op.regexp}/)\n"
      when CharRange
        ss = save()
        if op.start.bytesize == 1 and op.fin.bytesize == 1
          add "    #{ss} = self.pos\n"
          add "    _tmp = get_byte\n"
          add "    if _tmp\n", +1

          if op.start.respond_to? :getbyte
            left  = op.start.getbyte 0
            right = op.fin.getbyte 0
          else
            left  = op.start[0]
            right = op.fin[0]
          end

          add "    unless _tmp >= #{left} and _tmp <= #{right}\n"
          add "      self.pos = #{ss}\n"
          add "      _tmp = nil\n"
          add "    end\n"
          add "    end\n", -1
        else
          raise "Unsupported char range - #{op.inspect}"
        end
      when Choice
        ss = save()
        add "\n    #{ss} = self.pos\n"
        add "    while true # choice\n", +1
        op.ops.each_with_index do |n,idx|
          output_op code, n

          add "    break if _tmp\n"
          add "    self.pos = #{ss}\n"
          if idx == op.ops.size - 1
            add "    break\n"
          end
        end
        add "    end # end choice\n\n", -1
      when Multiple
        ss = save()
        if op.min == 0 and op.max == 1
          add "    #{ss} = self.pos\n"
          output_op code, op.op
          if op.save_values
            add "    @result = nil unless _tmp\n"
          end
          add "    unless _tmp\n"
          add "      _tmp = true\n"
          add "      self.pos = #{ss}\n"
          add "    end\n"
        elsif op.min == 0 and !op.max
          if op.save_values
            add "    _ary = []\n"
          end

          add "    while true\n", +1
          output_op code, op.op
          if op.save_values
            add "    _ary << @result if _tmp\n"
          end
          add "    break unless _tmp\n"
          add "    end\n", -1
          add "    _tmp = true\n"

          if op.save_values
            add "    @result = _ary\n"
          end

        elsif op.min == 1 and !op.max
          add "    #{ss} = self.pos\n"
          if op.save_values
            add "    _ary = []\n"
          end
          output_op code, op.op
          add "    if _tmp\n", +1
          if op.save_values
            add "      _ary << @result\n"
          end
          add "    while true\n", +1
          output_op code, op.op
          if op.save_values
            add "    _ary << @result if _tmp\n"
          end
          add "    break unless _tmp\n"
          add "    end\n", -1
          add "    _tmp = true\n"
          if op.save_values
            add "  @result = _ary\n"
          end
          add "  else\n" 
          add "    self.pos = #{ss}\n"
          add "  end\n"
        else
          add "  #{ss} = self.pos\n"
          add "  _count = 0\n"
          add "  while true\n", +1
          output_op code, op.op, -2
          add "  if _tmp\n"
          add "     _count += 1\n"
          add "     break if _count == #{op.max}\n"
          add "  else\n"
          add "     break\n"
          add "  end\n"
          add "  end\n", -1
          add "  if _count >= #{op.min}\n"
          add "    _tmp = true\n"
          add "  else\n"
          add "    self.pos = #{ss}\n"
          add "    _tmp = nil\n"
          add "  end\n"
        end

      when Sequence
        ss = save()
        add "\n    #{ss} = self.pos\n"
        add "    while true # sequence\n", +1
        op.ops.each_with_index do |n, idx|
          output_op code, n

          if idx == op.ops.size - 1
            add "    unless _tmp\n"
            add "      self.pos = #{ss}\n"
            add "    end\n"
            add "    break\n"
          else
            add "    unless _tmp\n"
            add "      self.pos = #{ss}\n"
            add "      break\n"
            add "    end\n"
          end
        end
        add "    end # end sequence\n\n", -1
      when AndPredicate
        ss = save()
        add "    #{ss} = self.pos\n"
        if op.op.kind_of? Action
          add "    _tmp = begin; #{op.op.action}; end\n"
        else
          output_op code, op.op
        end
        add "    self.pos = #{ss}\n"
      when NotPredicate
        ss = save()
        add "    #{ss} = self.pos\n"
        if op.op.kind_of? Action
          add "    _tmp = begin; #{op.op.action}; end\n"
        else
          output_op code, op.op
        end
        add "    _tmp = _tmp ? nil : true\n"
        add "    self.pos = #{ss}\n"
      when RuleReference
        add "    _tmp = apply(:#{method_name op.rule_name})\n"
      when InvokeRule
        if op.arguments
          add "    _tmp = #{method_name op.rule_name}#{op.arguments}\n"
        else
          add "    _tmp = #{method_name op.rule_name}()\n"
        end
      when Tag
        if op.tag_name and !op.tag_name.empty?
          output_op code, op.op
          add "    #{op.tag_name} = @result\n"
        else
          output_op code, op.op
        end
      when Action
        add "    @result = begin; "
        add op.action << "; end\n"
        if @debug
          add "    puts \"   => \" #{op.action.dump} \" => \#{@result.inspect} \\n\"\n"
        end
        add "    _tmp = true\n"
      when Collect
        add "    _text_start = self.pos\n"
        output_op code, op.op
        add "    if _tmp\n"
        add "      text = get_text(_text_start)\n"
        add "    end\n"
      else
        @indent -= indent_adjust
        raise "Unknown op - #{op.class}"
      end
      @indent -= indent_adjust
      
    end

    def standalone_region(path)
      cp = File.read(path)
      start = cp.index("# STANDALONE START")
      fin = cp.index("# STANDALONE END")

      return nil unless start and fin
      cp[start..fin]
    end

    def output
      return @output if @output
      if @standalone
        code = "class #{@name}\n"

        unless cp = standalone_region(
                    File.expand_path("../compiled_parser.rb", __FILE__))

          puts "Standalone failure. Check compiler_parser.rb for proper boundary comments"
          exit 1
        end

        unless pp = standalone_region(
                    File.expand_path("../position.rb", __FILE__))
          puts "Standalone failure. Check position.rb for proper boundary comments"
        end

        cp.gsub!(/include Position/, pp)
        code << cp << "\n"
      else
        code =  "require 'kpeg/compiled_parser'\n\n"
        code << "class #{@name} < KPeg::CompiledParser\n"
      end

      @grammar.setup_actions.each do |act|
        code << "\n#{act.action}\n\n"
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
        rule = @grammar.rules[name]

        rend = GrammarRenderer.escape renderings[name]
        code << "  Rules[:#{method_name name}] = rule_info(\"#{name}\", \"#{rend}\")\n"
      end

      code << "end\n"
      @output = code
    end

    def make(str)
      m = Module.new
      m.module_eval output

      cls = m.const_get(@name)
      cls.new(str)
    end

    def parse(str)
      make(str).parse
    end
  end
end
