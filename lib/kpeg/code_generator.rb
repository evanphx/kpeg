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

    def output_op(code, op)
      case op
      when Dot
        code << "    _tmp = get_byte\n"
      when LiteralString
        code << "    _tmp = match_string(#{op.string.dump})\n"
      when LiteralRegexp
        code << "    _tmp = scan(/\\A#{op.regexp}/)\n"
      when CharRange
        if op.start.bytesize == 1 and op.fin.bytesize == 1
          code << "    _tmp = get_byte\n"
          code << "    if _tmp\n"
          left  = op.start[0]
          right = op.fin[0]

          code << "      unless _tmp >= #{left} and _tmp <= #{right}\n"
          code << "        fail_range('#{op.start}', '#{op.fin}')\n"
          code << "        _tmp = nil\n"
          code << "      end\n"
          code << "    end\n"
        else
          raise "Unsupported char range - #{op.inspect}"
        end
      when Choice
        ss = save()
        code << "\n    #{ss} = self.pos\n"
        code << "    while true # choice\n"
        op.ops.each_with_index do |n,idx|
          output_op code, n

          code << "    break if _tmp\n"
          code << "    self.pos = #{ss}\n"
          if idx == op.ops.size - 1
            code << "    break\n"
          end
        end
        code << "    end # end choice\n\n"
      when Multiple
        ss = save()
        if op.min == 0 and op.max == 1
          code << "    #{ss} = self.pos\n"
          output_op code, op.op
          if op.save_values
            code << "    @result = nil unless _tmp\n"
          end
          code << "    unless _tmp\n"
          code << "      _tmp = true\n"
          code << "      self.pos = #{ss}\n"
          code << "    end\n"
        elsif op.min == 0 and !op.max
          if op.save_values
            code << "    _ary = []\n"
          end

          code << "    while true\n"
          output_op code, op.op
          if op.save_values
            code << "    _ary << @result if _tmp\n"
          end
          code << "    break unless _tmp\n"
          code << "    end\n"
          code << "    _tmp = true\n"

          if op.save_values
            code << "    @result = _ary\n"
          end

        elsif op.min == 1 and !op.max
          code << "    #{ss} = self.pos\n"
          if op.save_values
            code << "    _ary = []\n"
          end
          output_op code, op.op
          code << "    if _tmp\n"
          if op.save_values
            code << "      _ary << @result\n"
          end
          code << "      while true\n"
          code << "    "
          output_op code, op.op
          if op.save_values
            code << "        _ary << @result if _tmp\n"
          end
          code << "        break unless _tmp\n"
          code << "      end\n"
          code << "      _tmp = true\n"
          if op.save_values
            code << "      @result = _ary\n"
          end
          code << "    else\n"
          code << "      self.pos = #{ss}\n"
          code << "    end\n"
        else
          code << "    #{ss} = self.pos\n"
          code << "    _count = 0\n"
          code << "    while true\n"
          code << "  "
          output_op code, op.op
          code << "      if _tmp\n"
          code << "        _count += 1\n"
          code << "        break if _count == #{op.max}\n"
          code << "      else\n"
          code << "        break\n"
          code << "      end\n"
          code << "    end\n"
          code << "    if _count >= #{op.min}\n"
          code << "      _tmp = true\n"
          code << "    else\n"
          code << "      self.pos = #{ss}\n"
          code << "      _tmp = nil\n"
          code << "    end\n"
        end

      when Sequence
        ss = save()
        code << "\n    #{ss} = self.pos\n"
        code << "    while true # sequence\n"
        op.ops.each_with_index do |n, idx|
          output_op code, n

          if idx == op.ops.size - 1
            code << "    unless _tmp\n"
            code << "      self.pos = #{ss}\n"
            code << "    end\n"
            code << "    break\n"
          else
            code << "    unless _tmp\n"
            code << "      self.pos = #{ss}\n"
            code << "      break\n"
            code << "    end\n"
          end
        end
        code << "    end # end sequence\n\n"
      when AndPredicate
        ss = save()
        code << "    #{ss} = self.pos\n"
        output_op code, op.op
        code << "    self.pos = #{ss}\n"
      when NotPredicate
        ss = save()
        code << "    #{ss} = self.pos\n"
        output_op code, op.op
        code << "    self.pos = #{ss}\n"
        code << "    _tmp = _tmp ? nil : true\n"
      when RuleReference
        code << "    _tmp = apply('#{op.rule_name}', :#{method_name op.rule_name})\n"
      when Tag
        if op.tag_name and !op.tag_name.empty?
          output_op code, op.op
          code << "    #{op.tag_name} = @result\n"
        else
          output_op code, op.op
        end
      when Action
        code << "    @result = begin; "
        code << op.action << "; end\n"
        if @debug
          code << "    puts \"   => \" #{op.action.dump} \" => \#{@result.inspect} \\n\"\n"
        end
        code << "    _tmp = true\n"
      when Collect
        code << "    _text_start = self.pos\n"
        output_op code, op.op
        code << "    if _tmp\n"
        code << "      set_text(_text_start)\n"
        code << "    end\n"
      else
        raise "Unknown op - #{op.class}"
      end

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

      @grammar.rule_order.each do |name|
        rule = @grammar.rules[name]
        io = StringIO.new
        render.render_op io, rule.op

        rend = io.string
        rend.gsub! "\n", " "

        code << "\n"
        code << "  # #{name} = #{rend}\n"
        code << "  def #{method_name name}\n"
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

        code << "    return _tmp\n"
        code << "  end\n"
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
