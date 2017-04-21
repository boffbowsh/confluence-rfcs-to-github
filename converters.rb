require 'reverse_markdown'

module Converters
  class StructuredMacro < ReverseMarkdown::Converters::Base
    def convert(node, state={})
      if node['ac:name'] == 'info'
        status = node
          .css('tr:last-child td:first-child parameter')
          .select { |n| n['ac:name'] == 'title' }
          .first
          .content

        notes = node.at_css('tr:last-child td:last-child').content

        <<-EOF
---
status: "#{status}"
notes: "#{notes}"
---
        EOF
      else
        ""
      end
    rescue
      ""
    end
  end

  class UserLink < ReverseMarkdown::Converters::Base
    def convert(node, state={})
      parser = ReverseMarkdown.config.instance_variable_get(:@inline_options)[:confluence_parser]
      user = parser.by_id(node['ri:userkey'])
      user.name
    end
  end

  class Code < ReverseMarkdown::Converters::Base
    def convert(node, state = {})
      xml = node.to_s.gsub(%r{<inline-comment-marker ac:ref="(.*?)">}, '<inline-comment-marker>!!inline-comment-marker:\1!!</inline-comment-marker>')
      node = Nokogiri::XML(xml)
      "`#{node.text}`"
    end
  end

  class InlineComment < ReverseMarkdown::Converters::Base
    def convert(node, state={})
      "!!inline-comment-marker:#{node['ac:ref']}!!" + treat_children(node, state)
    end
  end

  class Emoticon < ReverseMarkdown::Converters::Base
    def convert(node, state={})
      ":#{node['ac:name'].sub('-','')}:"
    end
  end
end

ReverseMarkdown::Converters.register "placeholder", ReverseMarkdown::Converters::Ignore.new
ReverseMarkdown::Converters.register "structured-macro", Converters::StructuredMacro.new
ReverseMarkdown::Converters.register "user", Converters::UserLink.new
ReverseMarkdown::Converters.register "inline-comment-marker", Converters::InlineComment.new
ReverseMarkdown::Converters.register "code", Converters::Code.new
ReverseMarkdown::Converters.register "emoticon", Converters::Emoticon.new
