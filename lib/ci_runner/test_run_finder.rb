# frozen_string_literal: true

module CIRunner
  module TestRunFinder
    extend self

    def self.find(name = nil, check_runs)
      if check_runs["total_count"].zero?
        raise("There is no CI check on this commit.")
      end

      failed_checks = select_failed_checks(check_runs["check_runs"])

      if failed_checks.count.zero?
        raise("No CI check failed on this commit. There will be no failing tests to run.")
      end

      failed_checks.find { |run| run["name"] == name } || not_found(name, failed_checks)
    end

    private

    def select_failed_checks(checks)
      failed_conclusions = ["failure"]

      checks.select { |check| failed_conclusions.include?(check["conclusion"]) }
    end

    def not_found(name, checks)
      possible_names = checks.map { |check| check["name"] }

      raise(<<~EOM)
        Couldn't find a CI Check run with the name '#{name}'.

        Possible CI check names are:

        #{possible_names.join("\n")}
      EOM
    end
  end
end
