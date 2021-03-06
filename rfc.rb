require 'yaml'
require 'active_support/core_ext/hash/keys'

class RFC
  attr_reader :pages, :parser, :inline_comments
  def initialize(pages, parser)
    @pages = pages.sort_by { |page| page.version.to_i }
    @parser = parser
  end

  def number
    rfc_match = %r{^RFC.([0-9]+)}.match(pages.last.title)
    return nil unless rfc_match
    rfc_match[1].to_i
  end

  def pages_to_add
    @pages_to_add ||= begin
      old_name = nil
      pages.map do |page|
        next if page.bodyContents.first.body.strip == ""

        new_name = "#{page.title.parameterize}.md".sub(/^rfc-#{number}/, "rfc-#{number.to_s.rjust(3, '0')}")

        markdown, data = extract_yaml_frontmatter(markdown(page))
        contents = parse_inline_comments!(markdown)

        {
          old_name: old_name,
          new_name: old_name = new_name,
          contents: contents,
          message: page.versionComment,
          author: page.creator.name,
          date: page.lastModificationDate,
          page_id: page.id,
          data: data,
        }
      end.compact
    end
  end

  def title
    pages.last.title
  end

  def filename
    "#{pages.last.title.parameterize}.md".sub(/^rfc-#{number}/, "rfc-#{number.to_s.rjust(3, '0')}")
  end

  def branch
    "rfc-#{number}"
  end

  def markdown(page)
    ReverseMarkdown.convert(
      page.bodyContents.first.body,
      unknown_tags: :bypass,
      github_flavored: true,
      confluence_parser: parser,
    )
  end

  def extract_yaml_frontmatter(markdown)
    data = {}
    if markdown.each_line.first == "---\n"
      re = %r{---\n(.*)---\n+}m
      yaml = re.match(markdown)[1]
      data = YAML.load(yaml).stringify_keys
      markdown.gsub!(re, '')
    end

    [markdown, data]
  end

  def comments
    @comments ||= begin
      root_comments = child_comments_map
        .keys
        .reject { |c| c.property('parent').is_a? ConfluenceObject }
        .reject { |c| comment_is_inline? c }

      root_comments.map do |root_comment|
        output_comment(root_comment)
      end.flatten.compact
    end
  end

  def output_comment(comment)
    [
      format_comment(comment),
      (child_comments_map[comment] || []).map { |c| output_comment(c) }
    ]
  end

  def child_comments_map
    @child_comments_map ||= pages.last.comments.inject({}) do |map, comment|
      map[comment] ||= []
      if comment.property('parent').is_a? ConfluenceObject
        map[comment.parent] ||= []
        map[comment.parent] << comment
      end
      map
    end
  end

  def comment_is_inline?(comment)
    comment.contentProperties.any? do |cp|
      cp.name == 'inline-comment' && cp.stringValue == 'true'
    end
  end

  def format_comment(comment, inline: false)
    markdown = ""
    markdown += %{<a name="confluence-comment-#{comment.id}">} unless inline
    markdown += "By #{comment.creator.name} on #{comment.creationDate}\n"
    if !inline && comment.parent.is_a?(ConfluenceObject)
      markdown += "[in reply to #{comment.parent.creator.name}]"
      markdown += "(#user-content-confluence-comment-#{comment.parent.id})\n"
    end
    markdown += "\n#{markdown(comment)}"
  end

  def parse_inline_comments!(markdown)
    pattern = %r{!!inline-comment-marker:(.*)!!}
    @inline_comment_lines = {}
    markdown.each_line.with_index.map do |line, index|
      if matches = pattern.match(line)
        @inline_comment_lines[matches[1]] = index + 1
      end
      line.gsub(pattern, '')
    end.join
  end

  def inline_comments
    @inline_comments ||= child_comments_map.keys.select {|c| comment_is_inline?(c) }.map do |inline_comment|
      prop = inline_comment
        .contentProperties
        .detect { |cp| cp.name == 'inline-marker-ref' }

      next unless prop
      ref = prop.stringValue

      next unless @inline_comment_lines[ref]

      replies = (child_comments_map[inline_comment] || []).sort_by(&:creationDate)

      {
        comment: format_comment(inline_comment),
        line: @inline_comment_lines[ref],
        replies: replies.map { |c| format_comment(c, inline: true) },
      }
    end.compact
  end

  def status_text
    pages_to_add.last[:data]["status"]
  end

  def notes
    pages_to_add.last[:data]["notes"].blank? ? nil : pages_to_add.last[:data]["notes"]
  end

  def status_action
    case status_text
    when %r{CLOSED|REJECTED}
      :close
    when %r{ACCEPTED|AGREED|APPROVED|COMPLETED?|PASSED}
      :merge
    else
      :open
    end
  end
end
