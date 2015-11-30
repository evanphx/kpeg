module TinyMarkdown
  class Node
    def to_html
      if !self.respond_to?(:content)
        return ""
      end
      if self.content.kind_of?(Array)
        self.content.map(&:to_html).join("")
      elsif self.content.kind_of?(TinyMarkdown::Node)
        self.content.to_html
      elsif self.content
        self.content.to_s
      else
        ""
      end
    end

    def inspect
      if self.respond_to?(:content)
        '#<'+self.class.to_s+' content="'+self.content.to_s+'">'
      else
        '#<'+self.class.to_s+'>'
      end
    end
  end

  class HeadlineNode
    def to_html
      children = self.content.map(&:to_html).join("")
      "<h#{level}>#{children}</h#{level}>\n"
    end
  end

  class TextNode
    def to_html
      self.content.to_s
    end
  end

  class BlockQuoteNode
    def to_html
      children = self.content.map(&:to_html).join("")
      "<blockquote>#{children}</blockquote>\n"
    end
  end

  class BulletListNode
    def to_html
      children = self.content.map(&:to_html).join("")
      "<ul>\n#{children}</ul>\n"
    end
  end

  class BulletListItemNode
    def to_html
      children = self.content.map(&:to_html).join("")
      "<li>#{children}</li>\n"
    end
  end

  class PlainNode
    def to_html
      self.content.map(&:to_html).join("")
    end
  end

  class ParaNode
    def to_html
      children = self.content.map(&:to_html).join("")
      "<p>#{children}</p>\n"
    end
  end

  class VerbatimNode
    def to_html
      children = self.content.map(&:to_html).join("")
      "<pre><code>#{children}</code></pre>\n"
    end
  end

  class InlineElementNode
    def to_html
      children = self.content.map(&:to_html).join("")
      "<#{self.name}>#{children}</#{self.name}>"
    end

    def inspect
        '#<'+self.class.to_s+' name="'+self.name.to_s+'" content="'+self.content.to_s+'">'
    end
  end

  class LineBreakNode
    def to_html
      "<br />\n"
    end

    def inspect
      "\\n"
    end
  end

  class HorizontalRuleNode
    def to_html
      "<hr />\n"
    end
  end
end
