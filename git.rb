class Git
  PATHNAME = File.expand_path('output', '.')
  REPOSITORY = ENV['REPOSITORY'] || 'https://github.com/alphagov/govuk-rfcs.git'
  AUTHOR = ENV['AUTHOR'] || 'govuk-tech-members'

  class << self
    def init
      FileUtils.rm_rf PATHNAME
      FileUtils.mkdir_p PATHNAME
      git 'init'
    end

    def checkout(name)
      if git 'rev-parse', name, silent: true
        git 'checkout', name
      else
        git 'checkout', '-b', name
      end
    end

    def add(old_name: nil, new_name:, contents:, message: nil, author: AUTHOR, date: Time.now.to_s, page_id: nil)
      if old_name && old_name != new_name
        git 'mv', old_name, new_name
      end

      File.write(new_name, contents)
      git 'add', new_name

      message = nil if message == ''
      message ||= "Update #{new_name}"

      message << "\nOriginal url: https://gov-uk.atlassian.net/wiki/pages/viewpage.action?pageId=#{page_id}" if page_id

      t = Tempfile.new('message')
      t.write(message)
      t.close

      author = "'#{author.sub('.', ' ').titleize} <#{author}@digital.cabinet-office.gov.uk>'"

      git 'commit', '-F', t.path, '--author', author, '--date', "'#{date}'"

      t.unlink
    end

    def add_remote
      git 'remote', 'add', 'origin', REPOSITORY
    end

    def push_all
      git "push origin --all --force"
    end

    private
    def git(*args, silent: false)
      FileUtils.cd PATHNAME
      cmd = (['git'] + args.flatten).join(' ')
      if silent
        %x{#{cmd}}
      else
        system cmd
      end
      $?.exitstatus == 0
    end
  end
end
