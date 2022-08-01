# frozen_string_literal: true

module CIRunner
  module TestRunFinder
    extend self

    # Makes a request to GitHub to retrieve the checks for a commit. Display a nice UI with
    # a spinner while the user wait.
    #
    # @param repository [String] The full repository name, including the owner (i.e. rails/rails)
    # @param commit [String] The Git commit that has been pushed to GitHub and for which we'll retrieve the CI checks.
    # @param block [Proc, Lambda] A proc that will be called in case we can't retrieve the CI Checks.
    #   This allows the CLI to prematurely exit and let the CLI::UI closes its frame.
    #
    # @return [Hash] See GitHub documentation
    #
    # @see https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference
    def fetch_ci_checks(repository, commit, &block)
      github_client = GithubClient.new(Configuration::User.instance.github_token)
      ci_checks = {}
      error = nil

      title = "Fetching failed CI checks from GitHub for commit {{info:#{commit[..12]}}}"
      ::CLI::UI.spinner(title, auto_debrief: false) do
        ci_checks = github_client.check_runs(repository, commit)
      rescue GithubClient::Error => e
        error = e

        ::CLI::UI::Spinner::TASK_FAILED
      end

      block.call(error) if error

      ci_checks
    end

    # Find the CI check the user requested from the list of upstream checks.
    # This method is useful only when the user passes the `--run-name` flag to `ci-runner`. This makes
    # sure the CI check actually exists.
    #
    # @param ci_checks [Hash] The response from the previous +fetch_ci_checks+ request.
    # @param run_name [String] The name of the CI run that the user would like to retry on its machine.
    #
    # @return [Hash] A single check run from the list of +ci_checks+
    #
    # @raise [Error] If no CI checks with the given +run_name+ could be found.
    # @raise [Error] If the CI check was successfull. No point to continue as there should be no tests to rerun.
    def find(ci_checks, run_name)
      check_run = ci_checks["check_runs"].find { |check_run| check_run["name"] == run_name }
      raise(Error, no_check_message(ci_checks, run_name)) if check_run.nil?
      raise(Error, check_succeed(run_name)) if check_run["conclusion"] == "success"

      check_run
    end

    # Try to guess which runner (Minitest, RSpec) was responsible for this log output.
    #
    # The runner is the most important part of CI Runner. It's what determine the failures for a CI log,
    # as well as how to rerun those only.
    #
    # @param ci_log [String] The log output from CI.
    #
    # @return [Runners::MinitestRunner, Runners::RSpec]
    #
    # @raise [Error] In case none of the runners could detect the log output.
    def detect_runner(ci_log)
      raise_if_not_found = lambda { raise(Error, "Couldn't detect the test runner") }

      runner = [Runners::MinitestRunner, Runners::RSpec].find(raise_if_not_found) do |runner|
        runner.match?(ci_log)
      end

      runner.new(ci_log)
    end

    private

    # @param [String] run_name The name of the CI check input or chosen by the user.
    #
    # @return [String] A error message to display.
    def check_succeed(run_name)
      "The CI check '#{run_name}' was successfull. There should be no failing tests to rerun."
    end

    # @param [Hash] ci_checks The list of CI checks previously by the +fetch_ci_checks+ method.
    # @param [String] run_name The name of the CI check input or chosen by the user.
    #
    # @return [String] A error message letting the user know why CI Runner couldn't continue.
    def no_check_message(ci_checks, run_name)
      possible_checks = ci_checks["check_runs"].map do |check_run|
        if check_run["conclusion"] == "success"
          "#{::CLI::UI::Glyph.lookup("v")} #{check_run["name"]}"
        else
          "#{::CLI::UI::Glyph.lookup("x")} #{check_run["name"]}"
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
