require 'faraday-http-cache'
require 'octokit'

require_relative 'git'

class Github
  REPOSITORY = Git::REPOSITORY.sub('https://github.com/', '').sub('.git', '')
  OWNER = REPOSITORY.split('/')[0]

  class << self
    def create_pr(branch, title)
      response = client.create_pull_request(REPOSITORY, 'master', branch, title)
      response.number
    end

    def pr_number(branch)
      client.pull_requests(REPOSITORY, head: "#{OWNER}:#{branch}").first[:number]
    end

    def add_comment(pr, message)
      client.add_comment(REPOSITORY, pr, message)
    end

    def pr_sha(pr)
      client.pull_request(REPOSITORY, pr).head.sha
    end

    def create_pr_comment(pr, sha, filename, position, comment)
      client.create_pull_request_comment(REPOSITORY, pr, comment, sha, filename, position).id
    end

    def create_pr_comment_reply(pr, comment_id, comment)
      client.create_pull_request_comment_reply(REPOSITORY, pr, comment, comment_id)
    end

    def close_pr(pr)
      client.close_pull_request(REPOSITORY, pr)
    end

    def merge_pr(pr)
      client.merge_pull_request(REPOSITORY, pr)
    end

    def next_available_pr_number
      prs = client.pull_requests(REPOSITORY,
        state: 'all',
        sort: 'created',
        direction: 'desc'
      )

      if prs.first
        prs.first[:number].to_i + 1
      else
        1
      end
    end

    def create_empty_pr
      close_pr(create_pr('dummy', 'dummy'))
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
