require 'faraday-http-cache'
require 'octokit'

require_relative 'git'

class Github
  class << self
    REPOSITORY = Git::REPOSITORY.sub('https://github.com/', '').sub('.git', '')

    def create_pr(branch, title)
      client.create_pull_request(REPOSITORY, 'master', branch, title)
    end

    private
    def client
      @client = begin
        stack = Faraday::RackBuilder.new do |builder|
          builder.use Faraday::HttpCache, serializer: Marshal, shared_cache: false
          builder.use Octokit::Response::RaiseError
          builder.adapter Faraday.default_adapter
        end
        Octokit.middleware = stack

        Octokit::Client.new(netrc: true)
      end
    end
  end
end
