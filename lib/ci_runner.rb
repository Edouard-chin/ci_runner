# frozen_string_literal: true

require_relative "ci_runner/version"

module CIRunner
  autoload :CLI,            "ci_runner/cli"
  autoload :GithubClient,   "ci_runner/github_client"
  autoload :TestRunFinder,  "ci_runner/test_run_finder"
  autoload :LogParser,      "ci_runner/log_parser"
  autoload :Suite,          "ci_runner/suite"
  autoload :TestRunner,     "ci_runner/test_runner"
  autoload :TestFailure,    "ci_runner/test_failure"
end
