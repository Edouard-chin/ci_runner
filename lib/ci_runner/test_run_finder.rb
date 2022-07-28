# frozen_string_literal: true

module CIRunner
  module TestRunFinder
    class PossibleRunErrors < Error
      attr_reader :run_names

      def initialize(run_names, chosen_run, msg = nil)
        @run_names = run_names
        @chosen_run = chosen_run

        if run_names.nil?
          super(msg)
        else
          super(message)
        end
      end

      def message
        if @chosen_run.empty?
          <<~EOM

            Multiple checks failed on your CI.
            Please pass the `--run-name` flag (`ci_runner --run-name <name>`) with one of these possible values:

            #{@run_names.join("\n")}
          EOM
        else
          <<~EOM
            Couldn't find a failed CI Check run with the name '#{@chosen_run}'.

            Failed CI check names:

            #{@run_names.join("\n")}
          EOM
        end
      end
    end

    extend self

    def self.fetch_ci_checks(repository, commit)
      github_client = GithubClient.new(UserConfiguration.instance.github_token)

      github_client.check_runs(repository, commit)
    end

    def self.find(checks, name)
      if checks["total_count"].zero?
        raise(Error, "There is no CI check on this commit.")
      end

      check_runs = checks["check_runs"]

      failed_checks = select_failed_checks(check_runs)

      if failed_checks.count.zero?
        raise(Error, <<~EOM)
          No CI check failed on this commit. There will be no failing tests to run.
          Checks on this commit:

          #{check_names(check_runs).join("\n")}
        EOM
      end

      if name
        failed_checks.find { |run| run["name"] == name } || not_found(name, failed_checks)
      else
        answer = ::CLI::UI.ask(
          "Multiple CI checks failed for this commit. Please choose the one you wish to re-run.",
          options: failed_checks.map { |check_run| check_run["name"] },
        )

        find(checks, answer)
      end
    end

    private

    def select_failed_checks(check_runs)
      failed_conclusions = ["failure"]

      check_runs.select { |check_run| failed_conclusions.include?(check_run["conclusion"]) }
    end

    def not_found(name, failed_check_runs)
      run_names = failed_check_runs.map { |check_run| check_run["name"] }

      raise(PossibleRunErrors.new(run_names, name))
    end

    def check_names(check_runs)
      emoji_mapping = {
        "action_required" => "\u{1f534}",
        "stale" => "\u{1f534}",
        "failure" => "\u{1f534}",
        "success" => "\u{1f7e2}",
        "timed_out" => "\u{231b}",
        "cancelled" => "\u{1F6ab}",
        "neutral" => "\u{1f937}",
        "skipped" => "\u{23ed}",
      }

      if !STDOUT.tty?
        check_runs.map { |check_run| "- #{check_run['name']}" }
      else
        check_runs.map do |check_run|
          conclusion = check_run['conclusion']

          "#{emoji_mapping[conclusion]} #{check_run['name']}"
        end
      end
    end
  end
end
