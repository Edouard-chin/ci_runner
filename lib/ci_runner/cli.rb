# frozen_string_literal: true

require "thor"

module CIRunner
  class CLI < Thor
    default_command :rerun

    # @return [Boolean]
    def self.exit_on_failure?
      true
    end

    desc "rerun", "Run failing tests from a CI."
    long_desc <<~EOM
      Main command of CI Runner. This command is meant to rerun tests that failed on a CI,
      on your locale machine, without having you copy/paste output from the CI logs onto your terminal.

      The +rerun+ command will do everything from grabbing the CI checks that failed on a GitHub commit,
      ask which one you'd like to rerun, download and parse the CI log output and run on your
      machine exactly the same tests from the failing CI.

      CI Runner is meant to replicate what failed on CI exactly the same way. Therefore, the SEED,
      the Ruby version as well as the Gemfile from the CI run will be used when running the test suite.

      All option on the +rerun+ command are optional. CI Runner will try to infer them from your repository,
      and if it can't it will let you know.

      Please note that CI Runner will **not** ensure that the Git HEAD of your local repository matches
      the commit that failed upstream.
    EOM
    option :commit, type: :string, desc: "The Git commit that was pushed to GitHub and has a failing CI. The HEAD commit of your local repository will be used by default." # rubocop:disable Layout/LineLength
    option :repository, type: :string, desc: "The repository on which the CI failed. The repository will be infered from your git remote by default.", banner: "catanacorp/catana" # rubocop:disable Layout/LineLength
    option :run_name, type: :string, desc: "The CI check you which to rerun in case multiple checks failed for a commit. CI Runner will prompt you by default." # rubocop:disable Layout/LineLength
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

      You can get a token from GitHub by following this link: https://github.com/settings/tokens/new?description=CI+Runner&scopes=repo # rubocop:disable Layout/LineLength
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

    # Retrieve all the GitHub CI checks for a given commit. Will be used to interactively prompt
    # the user which one to rerun.
    #
    # @param repository [String] The full repository name including the owner (rails/rails).
    # @param commit [String] A Git commit that has been pushed to GitHub and for which CI failed.
    #
    # @return [Hash] See the GitHub documentation.
    #
    # @raise [SystemExit] Early exit the process if the CI checks can't be retrieved.
    #
    # @see https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference
    def fetch_ci_checks(repository, commit)
      TestRunFinder.fetch_ci_checks(repository, commit) do |error|
        puts(<<~EOM)
          Couldn't fetch the CI checks. The response from GitHub was:

          #{error.message}
        EOM

        exit(false)
      end
    end

    # Download and cache the log for the GitHub check. Downloading the log allows CI Runner to parse it and detect
    # which test failed in order to run uniquely those on the user machine.
    #
    # @param repository [String] The full repository name including the owner (rails/rails).
    # @param commit [String]     A Git commit that has been pushed to GitHub and for which CI failed.
    # @param check_run [Hash]    The GitHub Check that failed. See #fetch_ci_checks.
    #
    # @return [String] The content of the CI log.
    #
    # @raise [SystemExit] Early exit the process if the CI checks can't be retrieved.
    #
    # @see https://docs.github.com/en/rest/actions/workflow-jobs#download-job-logs-for-a-workflow-run
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

    # Interatively ask the user which CI check to rerun in the case a commit has multiple failing checks.
    # This method only runs if the user has not passed the '--run-name' flag to ci_runner.
    # Will automatically select a check in the case where there is only one failing check.
    #
    # @param ci_checks [Hash] (See #fetch_ci_checks)
    #
    # @return [Hash] A single Check Run, the one that the user selected.
    #
    # @raise [CIRunner::Error] In case all the CI checks on this commit were successfull. In such case
    #   there is no need to proceed as there should be no failing tests to rerun.
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
