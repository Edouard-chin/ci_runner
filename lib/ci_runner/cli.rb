# frozen_string_literal: true

require "thor"
require "byebug"

module CIRunner
  class CLI < Thor
    default_command :rerun

    def self.exit_on_failure?
      true
    end

    desc "run", "Run failing tests from a CI."
    option :commit, type: :string
    option :repository, type: :string
    option :run_name, type: :string
    def rerun
      ::CLI::UI::StdoutRouter.enable

      runner = nil

      ::CLI::UI.frame("Preparing CI Runner") do
        Configuration::User.instance.validate_token!

        commit = options[:commit] || GitHelper.head_commit
        repository = options[:repository] || GitHelper.repository_from_remote
        ci_checks = fetch_ci_checks(repository, commit)

        run_name = options[:run_name] || ask_for_name(ci_checks)
        check_run = TestRunFinder.find(ci_checks, run_name)

        ci_log = fetch_ci_log(repository, commit, check_run)
        runner = TestRunFinder.detect_runner(ci_log)
        runner.parse!

        if runner.failures.count == 0
          # Error
        end
      rescue GithubClient::Error, Error => e
        ::CLI::UI.puts("\n{{red:#{e.message}}}", frame_color: :red)

        exit(false)
      end

      ::CLI::UI::Frame.open("Your test run is about to start") do
        runner.report
        runner.start!
      end
    end

    desc "github_token TOKEN", "Save a GitHub token in your config."
    long_desc <<~EOM
     Save a personal access GitHub token in the ~/.ci_runner/config.yml file.
     The GitHub token is required to fetch CI checks and download logs from repositories.

     You can get a token from GitHub by following this link: https://github.com/settings/tokens/new?description=CI+Runner&scopes=repo
    EOM
    def github_token(token)
      ::CLI::UI::StdoutRouter.enable

      ::CLI::UI.frame("Saving GitHub Token") do
        user = GithubClient.new(token).me
        Configuration::User.instance.save_github_token(token)

        ::CLI::UI.puts(<<~EOM)
          Hello {{warning:#{user["login"]}}}! {{success:Your token is valid!}}

          {{info:The token has been saved in this file: #{Configuration::User.instance.config_file}}}
        EOM
      rescue GithubClient::Error => e
        ::CLI::UI.puts("{{red:\nYour token doesn't seem to be valid. The response from GitHub was: #{e.message}}}")

        exit(false)
      end
    end

    private

    def fetch_ci_checks(repository, commit)
      TestRunFinder.fetch_ci_checks(repository, commit) do |error|
        puts(<<~EOM)
          Couldn't fetch the CI checks. The response from GitHub was:

          #{error.message}
        EOM

        exit(false)
      end
    end

    def fetch_ci_log(repository, commit, check_run)
      log = LogDownloader.new(commit, repository, check_run).fetch do |error|
        puts(<<~EOM)
          Couldn't fetch the CI log. The response from GitHub was:

          #{error.message}
        EOM

        exit(false)
      end

      log.read
    end

    def ask_for_name(ci_checks)
      check_runs = ci_checks["check_runs"]
      failed_runs = check_runs.reject { |check_run| check_run["conclusion"] == "success" }

      if failed_runs.count == 0
        raise(Error, "No CI checks failed on this commit.")
      elsif failed_runs.count == 1
        check_run = failed_runs.first["name"]

        ::CLI::UI.puts(<<~EOM)
          {{warning:Automatically selected the CI check #{check_run} because it's the only one failing.}}
        EOM

        check_run
      else
        ::CLI::UI.ask(
          "Multiple CI checks failed for this commit. Please choose the one you wish to re-run.",
          options: failed_runs.map { |check_run| check_run["name"] },
        )
      end
    end
  end
end
