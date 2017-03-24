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
      @client = Octokit::Client.new(netrc: true)
    end
  end
end
