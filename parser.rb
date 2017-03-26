require 'nokogiri'

require_relative 'confluence_object'

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
