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
status: #{status}
notes: #{notes}
---
        EOF
      else
        ""
      end
    rescue
      ""
    end
  end
end

ReverseMarkdown::Converters.register "placeholder", ReverseMarkdown::Converters::Ignore.new
ReverseMarkdown::Converters.register "structured-macro", Converters::StructuredMacro.new
