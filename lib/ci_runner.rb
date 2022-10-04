# frozen_string_literal: true

require "cli/ui"
require_relative "ci_runner/version"

module CIRunner
  Error = Class.new(StandardError)

  autoload :CLI,             "ci_runner/cli"
  autoload :GitHelper,       "ci_runner/git_helper"
  autoload :TestRunFinder,   "ci_runner/test_run_finder"
  autoload :LogDownloader,   "ci_runner/log_downloader"
  autoload :TestFailure,     "ci_runner/test_failure"
  autoload :VersionVerifier, "ci_runner/version_verifier"

  module Check
    autoload :Buildkite,          "ci_runner/check/buildkite"
    autoload :Github,             "ci_runner/check/github"
    autoload :CircleCI,           "ci_runner/check/circle_ci"
    autoload :Unsupported,        "ci_runner/check/unsupported"
    autoload :ConcurrentDownload, "ci_runner/check/concurrent_download"
  end

  module Client
    autoload :Error,                  "ci_runner/client/error"
    autoload :Github,                 "ci_runner/client/github"
    autoload :CircleCI,               "ci_runner/client/circle_ci"
    autoload :Buildkite,              "ci_runner/client/buildkite"
    autoload :AuthenticatedBuildkite, "ci_runner/client/authenticated_buildkite"
  end

  module Configuration
    autoload :User, "ci_runner/configuration/user"
    autoload :Project, "ci_runner/configuration/project"
  end

  module Runners
    autoload :MinitestRunner, "ci_runner/runners/minitest_runner"
    autoload :RSpec,          "ci_runner/runners/rspec"
  end
end
