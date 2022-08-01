# frozen_string_literal: true

require "cli/ui"
require_relative "ci_runner/version"

module CIRunner
  Error = Class.new(StandardError)

  autoload :CLI,            "ci_runner/cli"
  autoload :GithubClient,   "ci_runner/github_client"
  autoload :GitHelper,      "ci_runner/git_helper"
  autoload :TestRunFinder,  "ci_runner/test_run_finder"
  autoload :LogDownloader,  "ci_runner/log_downloader"
  autoload :TestFailure,    "ci_runner/test_failure"
  autoload :UserConfiguration,     "ci_runner/user_configuration"
  autoload :ProjectConfiguration,  "ci_runner/project_configuration"

  module Runners
    autoload :MinitestRunner, "ci_runner/runners/minitest_runner"
    autoload :RSpec,          "ci_runner/runners/rspec"
  end
end
