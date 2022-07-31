# frozen_string_literal: true

module CIRunner
  module TestRunFinder
    extend self

    def self.fetch_ci_checks(repository, commit)
      github_client = GithubClient.new(UserConfiguration.instance.github_token)

      github_client.check_runs(repository, commit)
    end

    private

    def select_failed_checks(check_runs)
      failed_conclusions = ["failure"]

      check_runs.select { |check_run| failed_conclusions.include?(check_run["conclusion"]) }
    end
  end
end
