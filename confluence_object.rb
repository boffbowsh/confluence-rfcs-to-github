require 'active_support/core_ext/module/attribute_accessors'

class ConfluenceObject
  attr_reader :element, :parser

  def self.new(element, parser)
    @_cache ||= {}
    @_cache[element.object_id] ||= allocate.tap{|o| o.send(:initialize, element, parser)}
  end

  def initialize(element, parser)
    @element = element
    @parser = parser
  end

  def id
    @id ||= element.at_xpath('.//id').content
  end

  def type
    @type ||= element['class']
  end

  def property(name)
    @properties ||= {}
    @properties[name] = from_ref_or_value(element.at_xpath(%{.//property[@name="#{name}"]}))
  end

  def collection(name)
    @collections ||= {}
    @collections[name] ||= element.xpath(%{.//collection[@name="#{name}"]/element}).map do |el|
      from_ref_or_value(el)
    end
  end

  def properties
    @properties ||= {}
    element.xpath('.//property').each do |el|
      @properties[el['name']] ||= from_ref_or_value(el)
    end
    @properties
  end

  def collections
    Hash[element.xpath('.//collections').map { |el| { el['name'] => collection(el['name']) } }]
  end

  def method_missing(attr)
    return property(attr.to_s) if property(attr.to_s)
    return collection(attr.to_s) if collection(attr.to_s)
    return super(attr)
  end

  def inspect
    attrs = {id: id}.merge(properties).merge(collections)
    attr_list = attrs.map do |k,v|
      v = case v
      when Array
        "[#{v.map(&:to_s).join(', ')}]"
      else
        v.to_s
      end
      "#{k}: #{v}"
    end
    "#{type}(#{attr_list.join(', ')})"
  end

  def to_s
    "#{type}(#{id})"
  end

  private

  def from_ref_or_value(element)
    return nil if element.nil?
    if element['class']
      parser.by_id(element.at_xpath('.//id').content)
    else
      element.content
    end
  end
end
