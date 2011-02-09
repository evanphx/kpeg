require 'kpeg/compiled_grammar'

module KPeg
  class CodeGenerator
    def initialize(name, gram, debug=false)
      @name = name
      @grammar = gram
      @debug = debug
    end

    def method_name(name)
      name = name.gsub("-","_hyphen_")
      "_#{name}"
    end

    def output_op(code, op)
      case op
      when Dot
        code << "    _tmp = get_byte\n"
      when LiteralString
        code << "    _tmp = match_string(#{op.string.dump})\n"
      when LiteralRegexp
        code << "    _tmp = scan(/#{op.regexp}/)\n"
      when CharRange
        if op.start.bytesize == 1 and op.fin.bytesize == 1
          code << "    _tmp = get_byte\n"
          code << "    if _tmp\n"
          left  = op.start[0]
          right = op.fin[0]

          code << "      unless _tmp >= #{left} and _tmp <= #{right}\n"
          code << "        unget_one\n"
          code << "        _tmp = nil\n"
          code << "      end\n"
          code << "    end\n"
        else
          raise "Unsupported char range - #{op.inspect}"
        end
      when Choice
        code << "\n    _save = self.pos\n"
        code << "    while true # choice\n"
        op.ops.each_with_index do |n,idx|
          output_op code, n

          if idx == op.ops.size - 1
            code << "    break\n"
          else
            code << "    break if _tmp\n"
            code << "    self.pos = _save\n"
          end
        end
        code << "    end # end choice\n\n"
      when Multiple
        if op.min == 0 and op.max == 1
          code << "    _save = self.pos\n"
          output_op code, op.op
          code << "    unless _tmp\n"
          code << "      _tmp = true\n"
          code << "      self.pos = _save\n"
          code << "    end\n"
        elsif op.min == 0 and !op.max
          code << "    while true\n"
          output_op code, op.op
          code << "    break unless _tmp\n"
          code << "    end\n"
          code << "    _tmp = true\n"
        elsif op.min == 1 and !op.max
          output_op code, op.op
          code << "    if _tmp\n"
          code << "      while true\n"
          code << "    "
          output_op code, op.op
          code << "        break unless _tmp\n"
          code << "      end\n"
          code << "      _tmp = true\n"
          code << "    end\n"
        else
          code << "    _count = 0\n"
          code << "    while true\n"
          code << "  "
          output_op code, op.op
          code << "      if _tmp\n"
          code << "        _count += 1\n"
          code << "      else\n"
          code << "        break\n"
          code << "      end\n"
          code << "    end\n"
          code << "    if _count >= #{op.min} and _count <= #{op.max}\n"
          code << "      _tmp = true\n"
          code << "    else\n"
          code << "      _tmp = nil\n"
          code << "    end\n"
        end
      when Sequence
        code << "\n    _save = self.pos\n"
        code << "    while true # sequence\n"
        op.ops.each_with_index do |n, idx|
          output_op code, n

          if idx == op.ops.size - 1
            code << "    unless _tmp\n"
            code << "      self.pos = _save\n"
            code << "    end\n"
            code << "    break\n"
          else
            code << "    unless _tmp\n"
            code << "      self.pos = _save\n"
            code << "      break\n"
            code << "    end\n"
          end
        end
        code << "    end # end sequence\n\n"
      when AndPredicate
        code << "    save = self.pos\n"
        output_op code, op.op
        code << "    self.pos = save\n"
      when NotPredicate
        code << "    save = self.pos\n"
        output_op code, op.op
        code << "    self.pos = save\n"
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

    def output
      code =  "class #{@name} < KPeg::CompiledGrammar\n"
      @grammar.rule_order.each do |name|
        rule = @grammar.rules[name]
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
    end

    def make(str)
      m = Module.new
      m.module_eval output

      cls = m.const_get(@name)
      cls.new(str)
    end

    def run(str)
      make(str).run
    end
  end
end
