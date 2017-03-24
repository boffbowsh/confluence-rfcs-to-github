require 'bundler/setup'
require 'nokogiri'
require 'reverse_markdown'
require 'active_support/core_ext/string/inflections'

require_relative 'confluence_object'
require_relative 'converters'
require_relative 'git'

class Parser
  attr_reader :document
  def initialize
    @document = File.open("entities.xml") { |f| Nokogiri::XML(f) }
  end

  def by_type(type, scope: nil)
    scope ||= document
    scope.xpath(%{//object[@class="#{type}"]}).map { |e| ConfluenceObject.new(e, self) }
  end

  def by_id(id)
    @by_id ||= {}
    @by_id[id] ||= ConfluenceObject.new(
      document.at_xpath(%{//object/id[contains(text(), "#{id}")]}).parent,
      self
    )
  end
end

if __FILE__ == $0
  parser = Parser.new

  Git.init
  Git.add(new_name: '.gitkeep', contents: '', message: 'Initial commit')

  pages = parser.by_type('Page')

  documents = pages
    .group_by(&:originalVersionId)

  documents.each do |original_id, grouped_pages|
    next if original_id.to_i == 0
    grouped_pages.sort_by! { |page| page.version.to_i }

    rfc_match = %r{^RFC.([0-9]+)}.match(grouped_pages.last.title)
    next unless rfc_match
    rfc_number = rfc_match[1]

    Git.checkout "master"
    Git.checkout "rfc-#{rfc_number}"

    last_name = nil
    grouped_pages.each do |page|
      next if page.bodyContents.first.body.strip == ""

      puts "#{page.version}: #{page.title}"
      filename = "#{page.title.parameterize}.md"

      md = ReverseMarkdown.convert(
        page.bodyContents.first.body,
        unknown_tags: :bypass,
        github_flavored: true,
      )

      Git.add(
        old_name: last_name,
        new_name: filename,
        contents: md,
        message: page.versionComment,
        author: page.creator.name
      )

      last_name = filename
    end
  end

  Git.add_remote
  Git.push_all
end

