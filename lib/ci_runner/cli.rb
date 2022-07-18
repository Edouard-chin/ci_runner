# frozen_string_literal: true

require "thor"
require "byebug"

module CIRunner
  class CLI < Thor
    default_command :rerun

    def self.exit_on_failure?
      true
    end

    desc "run", "run failing tests from a CI"
    option :commit, type: :string
    option :repository, type: :string
    option :run_name, type: :string, required: true
    def rerun
      commit = options[:commit] || GitHelper.head_commit
      repository = options[:repository] || GitHelper.repository_from_remote

      log_file = LogDownloader.new(commit, repository, options[:run_name], shell).fetch
      log_parser = LogParser.new(log_file)
      log_parser.parse

      if log_parser.failures.count.zero?
        return errored("Couldn't find any test failures from the CI logs.")
      end

      TestRunner.new(log_parser.failures, log_parser.seed, shell).run_failing_tests
    rescue GithubClient::Error, Error => e
      errored(e.message)
    end

    desc "github_token TOKEN", "Save a GitHub token in your config"
    def github_token(token)
      user = GithubClient.new(token).me

      UserConfiguration.instance.save_github_token(token)

      say("Hello #{user["login"]}! Your token has been saved successfully!", :green)
    rescue GithubClient::Error => e
      errored(<<~EOM)
        Your token doesn't seem to be valid. The response from GitHub was:

        #{e.message}
      EOM
    end

    private

    def errored(message)
      say_error(message, :red)
    end
  end
end
