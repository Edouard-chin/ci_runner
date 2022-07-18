# frozen_string_literal: true

require "open3"

module CIRunner
  module GitHelper
    extend self

    def head_commit
      stdout, _, status = Open3.capture3("git rev-parse HEAD")

      if status.success?
        stdout.rstrip
      else
        raise(Error, <<~EOM)
          Couldn't determine the commit. The commit is required to download the right CI logs.

          Please pass the `--commit` flag (ci_runner --commit <commit>)
        EOM
      end
    end

    def repository_from_remote
      stdout, _, status = Open3.capture3("git remote -v")

      if status.success?
        process_remotes(stdout)
      else
        raise(Error, <<~EOM)
          Couldn't determine the name of the repository.

          Please pass the `--repository` flag (ci_runner --repository <owner/repository_name>)
        EOM
      end
    end

    private

    def process_remotes(stdout)
      stdout.match(/remote#{remote_regex}/) do |match_data|
        return "#{match_data[1]}/#{match_data[2]}"
      end

      stdout.match(/origin#{remote_regex}/) do |match_data|
        return "#{match_data[1]}/#{match_data[2]}"
      end

      raise(Error, <<~EOM)
        Couldn't determine the repository name based on the git remote.

        Please pass the `--repository` flag (ci_runner --repository <owner/repository_name>)
      EOM
    end

    def remote_regex
      /\s+(?:git@|https:\/\/)github.com(?::|\/)([a-zA-Z0-9\-_\.]+)\/([a-zA-Z0-9\-_\.]+?)(?:\.git)?\s+\((?:fetch|push)\)/
    end
  end
end
