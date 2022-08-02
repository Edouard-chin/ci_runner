# frozen_string_literal: true

require "open3"

module CIRunner
  # A helper for the `ci_runner rerun` command to infer options automatically.
  # The goal being to have the user only type `ci_runner rerun` and have things work magically.
  #
  # The command line options passed by a user have precedence.
  module GitHelper
    extend self

    # Get the HEAD commit of the repository. This assumes the user runs the `ci-runner` command from
    # a repository.
    #
    # @return [String] The HEAD commit of the user's local repository.
    #
    # @raise [Error] In case the `git` subprocess returns an error.
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

    # Get the full repository name (including the owner, i.e. rails/rails) thanks to the Git remote.
    # This allows the user to not have to type `ci-runner rerun --repostitory catanacorp/catana` each time.
    #
    # @return [String] The full repository name
    #
    # @raise [Error] In case the `git` subprocess returns an error.
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

    # Try to get the right repository depending on the remotes. It's quite common to have two remotes when your
    # work on a forked project. The remote from the source project is regularly called: "remote".
    #
    # CI Runner will prioritize remotes with the following order:
    #
    # - remote
    # - origin
    # - anything else
    #
    # @param stdout [String] The output from the `git remote -v` command.
    #
    # @return [String] The full repository name.
    #
    # @raise [Error] In case there is no GitHub remote. CI Runner currently works with GitHub.
    #
    # @example When the remote is preferred
    #   `git remote -v
    #    remote  git@github.com:rails/rails.git (fetch)
    #    remote  git@github.com:rails/rails.git (push)
    #    origin  git@github.com:Edouard-chin/rails.git (fetch)
    #    origin  git@github.com:Edouard-chin/rails.git (push)
    #
    #    rails/rails will be returned.
    def process_remotes(stdout)
      stdout.match(/remote#{remote_regex}/) do |match_data|
        return "#{match_data[1]}/#{match_data[2]}"
      end

      stdout.match(/origin#{remote_regex}/) do |match_data|
        return "#{match_data[1]}/#{match_data[2]}"
      end

      stdout.match(/#{remote_regex}/) do |match_data|
        return "#{match_data[1]}/#{match_data[2]}"
      end

      raise(Error, <<~EOM)
        Couldn't determine the repository name based on the git remote.

        Please pass the `--repository` flag (ci_runner --repository <owner/repository_name>)
      EOM
    end

    # return [Regexp] The regex to detect the full repository name.
    def remote_regex
      %r{\s+(?:git@|https://)github.com(?::|/)([a-zA-Z0-9\-_\.]+)/([a-zA-Z0-9\-_\.]+?)(?:\.git)?\s+\((?:fetch|push)\)}
    end
  end
end
