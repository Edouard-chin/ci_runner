# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "date"

module CIRunner
  class VersionVerifierTest < Minitest::Test
    def setup
      Configuration::User.instance.load!

      @verifier = VersionVerifier.new
    end

    def test_check_version_is_false_when_it_was_checked_less_than_3_days_ago
      FileUtils.touch(@verifier.last_checked)
      mtime = File.stat(@verifier.last_checked).mtime

      refute_predicate(@verifier, :new_ci_runner_version?)
      assert_equal(mtime, File.stat(@verifier.last_checked).mtime)
    end

    def test_check_version_runs_when_it_was_never_checked
      stub_request(:get, "https://api.github.com/repos/Edouard-chin/ci_runner/releases/latest")
        .to_return_json(status: 200, body: { tag_name: "v5.0.0" })

      refute_predicate(@verifier.last_checked, :exist?)

      @verifier.new_ci_runner_version?

      assert_requested(:get, "https://api.github.com/repos/Edouard-chin/ci_runner/releases/latest")
      assert_predicate(@verifier.last_checked, :exist?)
    end

    def test_check_version_is_true_when_it_was_checked_more_than_3_days_ago
      ten_days_ago = Time.now - 864_000
      FileUtils.touch(@verifier.last_checked, mtime: ten_days_ago)

      stub_request(:get, "https://api.github.com/repos/Edouard-chin/ci_runner/releases/latest")
        .to_return_json(status: 200, body: { tag_name: "v5.0.0" })

      assert_predicate(@verifier, :new_ci_runner_version?)
      assert_equal(Date.today, File.stat(@verifier.last_checked).mtime.to_date)
    end

    def test_check_version_is_false_when_it_was_checked_more_than_3_days_ago_but_there_are_no_new
      ten_days_ago = Time.now - 864_000
      FileUtils.touch(@verifier.last_checked, mtime: ten_days_ago)

      stub_request(:get, "https://api.github.com/repos/Edouard-chin/ci_runner/releases/latest")
        .to_return_json(status: 200, body: { tag_name: "v#{VERSION}" })

      refute_predicate(@verifier, :new_ci_runner_version?)
      assert_equal(Date.today, File.stat(@verifier.last_checked).mtime.to_date)
    end
  end
end
