class RFC
  attr_reader :pages
  def initialize(pages)
    @pages = pages.sort_by { |page| page.version.to_i }
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

      contents = ReverseMarkdown.convert(
        page.bodyContents.first.body,
        unknown_tags: :bypass,
        github_flavored: true,
      )

      {
        old_name: old_name,
        new_name: new_name,
        contents: contents,
        message: page.versionComment,
        author: page.creator.name
      }
    end.compact
  end
end
