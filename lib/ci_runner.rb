# frozen_string_literal: true

require_relative "ci_runner/version"
require "cli/ui"

module CIRunner
  Error = Class.new(StandardError)

  autoload :CLI,            "ci_runner/cli"
  autoload :GithubClient,   "ci_runner/github_client"
  autoload :GitHelper,      "ci_runner/git_helper"
  autoload :TestRunFinder,  "ci_runner/test_run_finder"
  autoload :LogParser,      "ci_runner/log_parser"
  autoload :LogDownloader,  "ci_runner/log_downloader"
  autoload :Suite,          "ci_runner/suite"
  autoload :TestRunner,     "ci_runner/test_runner"
  autoload :TestFailure,    "ci_runner/test_failure"
  autoload :UserConfiguration,  "ci_runner/user_configuration"
end
