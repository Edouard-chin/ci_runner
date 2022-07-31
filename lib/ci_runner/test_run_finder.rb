# frozen_string_literal: true

module CIRunner
  module TestRunFinder
    extend self

    def fetch_ci_checks(repository, commit, &block)
      github_client = GithubClient.new(UserConfiguration.instance.github_token)
      ci_checks = {}
      error = nil

      ::CLI::UI.spinner("Fetching failed CI checks from GitHub for commit {{info:#{commit[..12]}}}", auto_debrief: false) do
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
      raise(Error.new(no_check_message(ci_checks, run_name))) if check_run.nil?
      raise(Error.new(check_succeed(run_name))) if check_run["conclusion"] == "success"

      check_run
    end

    private

    def check_succeed(run_name)
      "The CI check '#{run_name}' was successfull. There should be no failing tests to rerun."
    end

    def no_check_message(ci_checks, run_name)
      possible_checks = ci_checks["check_runs"].map do |check_run|
        if check_run["conclusion"] == "success"
          "#{::CLI::UI::Glyph.lookup('v')} #{check_run["name"]}"
        else
          "#{::CLI::UI::Glyph.lookup('x')} #{check_run["name"]}"
        end
      end

      if possible_checks.any?
        <<~EOM
          Couldn't find a CI check called '#{run_name}'.
          CI checks on this commit are:

          #{possible_checks.join("\n")}
        EOM
      else
        <<~EOM
          Couldn't find a CI check called '#{run_name}'.

          There are no CI checks on this commit.
        EOM
      end
    end
  end
end
