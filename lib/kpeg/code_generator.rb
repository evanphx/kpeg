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

    def output_node(code, node)
      case node
      when Dot
        code << "    _tmp = get_byte\n"
      when LiteralString
        code << "    _tmp = match_string(#{node.string.dump})\n"
      when LiteralRegexp
        code << "    _tmp = scan(/#{node.regexp}/)\n"
      when CharRange
        if node.start.bytesize == 1 and node.fin.bytesize == 1
          code << "    _tmp = get_byte\n"
          code << "    if _tmp\n"
          left  = node.start[0]
          right = node.fin[0]

          code << "      unless _tmp >= #{left} and _tmp <= #{right}\n"
          code << "        unget_one\n"
          code << "        _tmp = nil\n"
          code << "      end\n"
          code << "    end\n"
        else
          raise "Unsupported char range - #{node.inspect}"
        end
      when Choice
        code << "\n    _save = self.pos\n"
        code << "    while true # choice\n"
        node.rules.each_with_index do |n,idx|
          output_node code, n

          if idx == node.rules.size - 1
            code << "    break\n"
          else
            code << "    break if _tmp\n"
            code << "    self.pos = _save\n"
          end
        end
        code << "    end # end choice\n\n"
      when Multiple
        if node.min == 0 and node.max == 1
          code << "    _save = self.pos\n"
          output_node code, node.rule
          code << "    unless _tmp\n"
          code << "      _tmp = true\n"
          code << "      self.pos = _save\n"
          code << "    end\n"
        elsif node.min == 0 and !node.max
          code << "    while true\n"
          output_node code, node.rule
          code << "    break unless _tmp\n"
          code << "    end\n"
          code << "    _tmp = true\n"
        elsif node.min == 1 and !node.max
          output_node code, node.rule
          code << "    if _tmp\n"
          code << "      while true\n"
          code << "    "
          output_node code, node.rule
          code << "        break unless _tmp\n"
          code << "      end\n"
          code << "      _tmp = true\n"
          code << "    end\n"
        else
          code << "    _count = 0\n"
          code << "    while true\n"
          code << "  "
          output_node code, node.rule
          code << "      if _tmp\n"
          code << "        _count += 1\n"
          code << "      else\n"
          code << "        break\n"
          code << "      end\n"
          code << "    end\n"
          code << "    if _count >= #{node.min} and _count <= #{node.max}\n"
          code << "      _tmp = true\n"
          code << "    else\n"
          code << "      _tmp = nil\n"
          code << "    end\n"
        end
      when Sequence
        code << "\n    _save = self.pos\n"
        code << "    while true # sequence\n"
        node.rules.each_with_index do |n, idx|
          output_node code, n

          if idx == node.rules.size - 1
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
        output_node code, node.rule
        code << "    self.pos = save\n"
      when NotPredicate
        code << "    save = self.pos\n"
        output_node code, node.rule
        code << "    self.pos = save\n"
        code << "    _tmp = _tmp ? nil : true\n"
      when RuleReference
        code << "    _tmp = apply('#{node.rule_name}', :#{method_name node.rule_name})\n"
      when Tag
        if node.tag_name and !node.tag_name.empty?
          output_node code, node.rule
          code << "    #{node.tag_name} = @result\n"
        else
          output_node code, node.rule
        end
      when Action
        code << "    @result = begin; "
        code << node.action << "; end\n"
        code << "    _tmp = true\n"
      when Collect
        code << "    _text_start = self.pos\n"
        output_node code, node.rule
        code << "    if _tmp\n"
        code << "      set_text(_text_start)\n"
        code << "    end\n"
      else
        raise "Unknown node - #{node.class}"
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

        output_node code, rule
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
