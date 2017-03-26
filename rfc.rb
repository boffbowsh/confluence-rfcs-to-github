class RFC
  attr_reader :pages, :parser
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

      {
        old_name: old_name,
        new_name: new_name,
        contents: markdown(page),
        message: page.versionComment,
        author: page.creator.name
      }
    end.compact
  end

  def title
    pages.last.title
  end

  def branch
    "rfc-#{number}"
  end

  def markdown(page)
    ReverseMarkdown.convert(
      page.bodyContents.first.body,
      unknown_tags: :bypass,
      github_flavored: true,
      confluence_parser: parser
    )
  end

  def comments
    root_comments = child_comments_map
      .keys
      .reject { |c| comment_is_inline? c }

    root_comments.map do |root_comment|
      output_comment(root_comment)
    end.flatten.compact
  end

  def output_comment(comment)
    [
      format_comment(comment),
      (child_comments_map[comment] || []).map { |c| output_comment(c) }
    ]
  end

  def child_comments_map
    @child_comments_map ||= pages.last.comments.inject({}) do |map, comment|
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

  def format_comment(comment)
    string = %{<a name="confluence-comment-#{comment.id}">}
    string += "By #{comment.creator.name} on #{comment.creationDate}\n"
    if comment.parent.is_a? ConfluenceObject
      string += "[in reply to #{comment.parent.creator.name}]"
      string += "(#user-content-confluence-comment-#{comment.parent.id})\n"
    end
    string += "\n#{markdown(comment)}"
  end
end
