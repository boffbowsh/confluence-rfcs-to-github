require 'bundler/setup'
require 'nokogiri'
require 'reverse_markdown'

require_relative 'confluence_object'
require_relative 'converters'

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
    ConfluenceObject.new(
      document.at_xpath(%{//object/id[contains(text(), "#{id}")]}).parent,
      self
    )
  end
end

if __FILE__ == $0
  parser = Parser.new

  pages = parser.by_type('Page')

  documents = [pages.last]
    .group_by(&:originalVersionId)

  documents.each do |original_id, pages|
    puts original_id
    pages.sort_by! { |page| page.version.to_i }
    pages.each { |page| puts "#{page.version}: #{page.title}"}

    puts "====\n"

    md = ReverseMarkdown.convert(
      pages.last.bodyContents.first.body,
      unknown_tags: :bypass,
      github_flavored: true,
    )

    puts md
    break
  end
end

