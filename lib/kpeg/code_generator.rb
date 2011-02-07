module KPeg
  class CodeGenerator
    def initialize(name, gram)
      @name = name
      @grammar = gram
    end

    def method_name(name)
      name = name.gsub("-","_hyphen_")
      "_#{name}"
    end

    def output_node(code, node)
      case node
      when Dot
        code << "    _tmp = x.get_byte\n"
      when LiteralString
        code << "    _tmp = x.scan(/#{Regexp.quote node.string}/)\n"
      when LiteralRegexp
        code << "    _tmp = x.scan(/#{node.regexp}/)\n"
      when CharRange
        if node.start.bytesize == 1 and node.fin.bytesize == 1
          code << "    _tmp = x.get_byte\n"
          code << "    fix = _tmp[0]\n"
          left  = node.start[0]
          right = node.fin[0]

          code << "    _tmp = nil unless fix >= #{left} and fix <= #{right}\n"
        else
          raise "Unsupported char range - #{node.inspect}"
        end
      when Choice
        code << "\n    while true # choice\n"
        node.rules.each_with_index do |n,idx|
          output_node code, n

          if idx == node.rules.size - 1
            code << "    break\n"
          else
            code << "    break if _tmp\n"
          end
        end
        code << "    end # end choice\n\n"
      when Multiple
        if node.min == 0 and node.max == 1
          output_node code, node.rule
          code << "    _tmp = true unless _tmp\n"
        elsif node.min == 0 and !node.max
          code << "    ary = []\n"
          code << "    while true\n"
          code << "  "
          output_node code, node.rule
          code << "      if _tmp\n"
          code << "        ary << _tmp\n"
          code << "      else\n"
          code << "        break\n"
          code << "      end\n"
          code << "    end\n"
          code << "    _tmp = ary\n"
        elsif node.min == 1 and !node.max
          output_node code, node.rule
          code << "    if _tmp\n"
          code << "      ary = [_tmp]\n"
          code << "      while true\n"
          code << "    "
          output_node code, node.rule
          code << "        if _tmp\n"
          code << "          ary << _tmp\n"
          code << "        else\n"
          code << "          break\n"
          code << "        end\n"
          code << "      end\n"
          code << "      _tmp = ary\n"
          code << "    end\n"
        else
          code << "    ary = []\n"
          code << "    while true\n"
          code << "  "
          output_node code, node.rule
          code << "      if _tmp\n"
          code << "        ary << _tmp\n"
          code << "      else\n"
          code << "        break\n"
          code << "      end\n"
          code << "    end\n"
          code << "    if ary.size >= #{node.min} and ary.size <= #{node.max}\n"
          code << "      _tmp = ary\n"
          code << "    else\n"
          code << "      _tmp = nil\n"
          code << "    end\n"
        end
      when Sequence
        code << "\n    while true # sequence\n"
        node.rules.each_with_index do |n, idx|
          output_node code, n

          if idx == node.rules.size - 1
            code << "    break\n"
          else
            code << "    break unless _tmp\n"
          end
        end
        code << "    end # end sequence\n\n"
      when AndPredicate
        code << "    save = x.pos\n"
        output_node code, node.rule
        code << "    x.pos = save\n"
      when NotPredicate
        code << "    save = x.pos\n"
        output_node code, node.rule
        code << "    x.pos = save\n"
        code << "    _tmp = !_tmp\n"
      when RuleReference
        code << "    _tmp = x.find_memo('#{node.rule_name}')\n"
        code << "    unless _tmp\n"
        code << "      _tmp = #{method_name node.rule_name}(x)\n"
        code << "      x.set_memo('#{node.rule_name}', _tmp)\n"
        code << "    end\n"
      when Tag
        if node.tag_name and !node.tag_name.empty?
          output_node code, node.rule
          code << "    #{node.tag_name} = _tmp\n"
        else
          output_node code, node.rule
        end
      when Action
        code << "    _tmp = begin; "
        code << node.action << "; end\n"
      else
        raise "Unknown node - #{node.class}"
      end

    end

    def output
      code =  "class #{@name}\n"
      code << "  def root(x)\n"

      output_node code, @grammar.root

      code << "    return _tmp\n"
      code << "  end\n"
      code << "end\n"
    end
  end
end
