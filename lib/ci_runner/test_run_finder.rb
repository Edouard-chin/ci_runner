# frozen_string_literal: true

module CIRunner
  module TestRunFinder
    extend self

    def self.find(name = nil, checks)
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

      failed_checks.find { |run| run["name"] == name } || not_found(name, failed_checks)
    end

    private

    def select_failed_checks(check_runs)
      failed_conclusions = ["failure"]

      check_runs.select { |check_run| failed_conclusions.include?(check_run["conclusion"]) }
    end

    def not_found(name, failed_check_runs)
      raise(Error, <<~EOM)
        Couldn't find a failed CI Check run with the name '#{name}'.

        Failed CI check names with their status:

        #{check_names(failed_check_runs).join("\n")}
      EOM
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

          "#{emoji_mapping[conclusion]} #{check_run['name']} => #{conclusion}"
        end
      end
    end
  end
end
