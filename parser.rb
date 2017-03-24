require 'bundler/setup'
require 'nokogiri'
require 'reverse_markdown'
require 'active_support/core_ext/string/inflections'

require_relative 'confluence_object'
require_relative 'converters'
require_relative 'git'
require_relative 'rfc'

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

  documents = pages.group_by(&:originalVersionId)

  rfcs = documents.map do |originalVersionId, grouped_pages|
    next if originalVersionId.to_i == 0
    rfc = RFC.new(grouped_pages)
    rfc if rfc.number
  end.compact

  rfcs.each do |rfc|
    Git.checkout "master"
    Git.checkout "rfc-#{rfc.number}"

    rfc.pages_to_add.each do |page|
      Git.add(page)
    end
  end

  Git.add_remote
  Git.push_all
end

