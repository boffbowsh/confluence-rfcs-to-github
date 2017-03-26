require 'bundler/setup'
require 'nokogiri'
require 'reverse_markdown'
require 'active_support/core_ext/string/inflections'

require_relative 'confluence_object'
require_relative 'converters'
require_relative 'git'
require_relative 'github'
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
    next if ARGV[0] && originalVersionId.to_i != ARGV[0].to_i

    grouped_pages << parser.by_id(originalVersionId)
    grouped_pages.uniq!
    rfc = RFC.new(grouped_pages, parser)
    rfc if rfc.number
  end.compact

  rfcs.each do |rfc|
    Git.checkout "master"
    Git.checkout rfc.branch

    rfc.pages_to_add.each do |page|
      Git.add(page)
    end
  end

  Git.add_remote
  Git.push_all

  rfcs.each do |rfc|
    puts "Creating PR for RFC #{rfc.number}"
    begin
      pr_number = Github.create_pr(rfc.branch, rfc.title)
    rescue Octokit::UnprocessableEntity
      pr_number = Github.pr_number(rfc.branch)
    end

    sha = Github.pr_sha(pr_number)

    if rfc.comments.any?
      puts "Posting #{rfc.comments.count} comments"
    end
    rfc.comments.each do |comment|
      Github.add_comment(pr_number, comment)
    end

    if rfc.inline_comments.any?
      puts "Posting #{rfc.inline_comments.count} inline comments"
    end
    rfc.inline_comments.each do |comment|
      comment_id = Github.create_pr_comment(
        pr_number,
        sha,
        rfc.filename,
        comment[:line],
        comment[:comment],
      )

      comment[:replies].each do |reply|
        Github.create_pr_comment_reply(pr_number, comment_id, reply)
      end
    end
  end
end

