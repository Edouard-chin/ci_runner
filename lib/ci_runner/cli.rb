# frozen_string_literal: true

require "thor"
require "byebug"
require "cli/ui"

module CIRunner
  class CLI < Thor
    default_command :rerun

    def self.exit_on_failure?
      true
    end

    def ask_for_name(ci_checks)
      check_runs = ci_checks["check_runs"]
      failed_runs = check_runs.select { |check_run| check_run["conclusion"] == "failure" }

      if failed_runs.count == 0
        # errors
      elsif failed_runs.count == 1
        # print why
        failed_runs.first["name"]
      else
        ::CLI::UI.ask(
          "Multiple CI checks failed for this commit. Please choose the one you wish to re-run.",
          options: failed_runs.map { |check_run| check_run["name"] },
        )
      end
    end

    def find_run(ci_checks, run_name)
      check_run = ci_checks["check_runs"].find { |check_run| check_run["name"] == run_name }
      raise "No Check Run" if check_run.nil?
      raise "Check Run succeed" if check_run["conclusion"] == "success"

      check_run
    end

    desc "run", "run failing tests from a CI"
    option :commit, type: :string
    option :repository, type: :string
    option :run_name, type: :string
    def rerun
      ::CLI::UI::StdoutRouter.enable
      ::CLI::UI.frame("Preparing CI Runner")

      commit = options[:commit] || GitHelper.head_commit
      repository = options[:repository] || GitHelper.repository_from_remote
      ci_checks = []

      ::CLI::UI.spinner("Fetching failed CI checks from GitHub for commit {{info:#{commit[..12]}}}") do |spinner|
        ci_checks = TestRunFinder.fetch_ci_checks(repository, commit)
      end

      run_name = options[:run_name] || ask_for_name(ci_checks)
      check_run = find_run(ci_checks, run_name)

      log_file = LogDownloader.new(commit, repository, check_run).fetch
      log_parser = LogParser.new(log_file).tap(&:parse)

      if log_parser.failures.count == 0
        # Error
      end

      ::CLI::UI::Frame.close("Found {{warning:#{log_parser.failures.count}}} failing tests from the CI logs. Running them now.")

      ::CLI::UI::Frame.open("Re-running failing tests") do
        TestRunner.new(log_parser.failures, log_parser.seed).run_failing_tests
      end
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

    desc "play", "play"
    def play
      bla = nil

      ::CLI::UI.frame("Preparing CI Runner", success_text: "Hello!") do
        # ::CLI::UI.spinner("Fetching CI checks from GitHub") do |spinner|
          ::CLI::UI.ask("Multiple CI checks failed for this commit. Please choose the one you wish ", options: %w(rails go ruby python rails go ruby python rails go ruby python))
          # spinner.update_title("CI logs downloaded and cached.")
        # end
      end
    end

    private

    def errored(message)
      say_error(message, :red)
    end
  end
end
