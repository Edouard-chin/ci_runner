# frozen_string_literal: true

require "thor"
require "open3"
require "byebug"

module CIRunner
  class CLI < Thor
    default_command :rerun

    def self.exit_on_failure?
      true
    end

    desc "run", "run failing tests from a CI"
    option :commit, type: :string
    option :run_name, type: :string, required: true
    def rerun
      # commit = options[:commit] || head_commit

      # client = GithubClient.new("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")
      # check_runs = client.check_runs(commit)
      # check_run = TestRunFinder.find(options[:name], check_runs)

      # say("Downloading CI logs, this can take a few seconds...", :green)

      # logfile = client.download_log(check_run["id"])

      # say("CI logs downloaded. Now parsing for test failures...", :green)

      failures = LogParser.new(File.open("./open-uri20220718-94179-22vrpp")).parse

      if failures.count.zero?
        say_error("Couldn't find any test failures from the CI logs.", :red)

        exit(1)
      end

      TestRunner.new(failures).run_failing_tests
    rescue GithubClient::Error, StandardError => e
      say_error(e.message, :red)

      exit(1)
    end

    private

    def head_commit
      stdout, _, status = Open3.capture3("git rev-parse HEAD")

      if status.success?
        stdout.rstrip
      else
        say_error(<<~EOM, :red)
          Couldn't determine the commit. The commit is required to download the
          right CI logs.

          Please pass the `--commit` flag (ci_runner --commit <commit>)
        EOM

        exit(1)
      end
    end
  end
end
