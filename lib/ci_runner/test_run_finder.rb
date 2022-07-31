# frozen_string_literal: true

module CIRunner
  module TestRunFinder
    extend self

    def fetch_ci_checks(repository, commit, &block)
      github_client = GithubClient.new(UserConfiguration.instance.github_token)
      ci_checks = {}
      title = "Fetching failed CI checks from GitHub for commit {{info:#{commit[..12]}}}"
      error = nil

      ::CLI::UI.spinner(title, auto_debrief: false) do |spinner|
        ci_checks = github_client.check_runs(repository, commit)
      rescue GithubClient::Error => e
        error = e

        ::CLI::UI::TASK_FAILED
      end

      block.call(error) if error

      ci_checks
    end

    def find(ci_checks, run_name)
      check_run = ci_checks["check_runs"].find { |check_run| check_run["name"] == run_name }
      raise "No Check Run" if check_run.nil?
      raise "Check Run succeed" if check_run["conclusion"] == "success"

      check_run
    end
  end
end
