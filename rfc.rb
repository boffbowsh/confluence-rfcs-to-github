class RFC
  attr_reader :pages, :parser, :inline_comments
  def initialize(pages, parser)
    @pages = pages.sort_by { |page| page.version.to_i }
    @parser = parser
  end

  def number
    rfc_match = %r{^RFC.([0-9]+)}.match(pages.last.title)
    return nil unless rfc_match
    rfc_number = rfc_match[1]
  end

  def pages_to_add
    old_name = nil
    pages.map do |page|
      next if page.bodyContents.first.body.strip == ""

      new_name = "#{page.title.parameterize}.md"

      contents = parse_inline_comments!(markdown(page))

      {
        old_name: old_name,
        new_name: old_name = new_name,
        contents: contents,
        message: page.versionComment,
        author: page.creator.name
      }
    end.compact
  end

  def title
    pages.last.title
  end

  def filename
    "#{pages.last.title.parameterize}.md"
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

  def comments
    @comments ||= begin
      root_comments = child_comments_map
        .keys
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
end
