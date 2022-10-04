# frozen_string_literal: true

require "test_helper"
require "fileutils"

module CIRunner
  class CLITest < Minitest::Test
    def setup
      Configuration::User.instance.load!
      Configuration::User.instance.save_github_token("abc")
      FileUtils.touch(VersionVerifier.new.last_checked)

      super
    end

    def test_rerun_when_user_has_not_set_a_token_first
      Configuration::User.instance.config_file.delete
      Configuration::User.instance.load!

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar"])
      rescue SystemExit
        nil
      end

      refute_match("A newer version of CI Runner is available.", stdout)
      assert_match("GitHub token needs to be saved into your configuration before being able to use CI Runner", stdout)
      assert_match(/mHave a look at the .*ci_runner help github_token.* command./, stdout)
    end

    def test_rerun_when_no_checks_failed
      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: { total_count: 0, check_runs: [] })

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/statuses")
        .to_return_json(status: 200, body: "[]")

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar"])
      rescue SystemExit
        nil
      end

      assert_match("No CI checks failed on this commit.", stdout)
    end

    def test_rerun_when_log_downloading_fails
      ci_check_response = {
        total_count: 2,
        check_runs: [
          { "name": "Ruby Test 3.0", id: 1, "conclusion" => "failure", app: { slug: "github-actions" } },
          { "name": "Ruby Test 3.1", id: 2, "conclusion" => "success", app: { slug: "github-actions" } },
        ],
      }

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: ci_check_response)

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/statuses")
        .to_return_json(status: 200, body: "[]")

      stub_request(:get, "https://api.github.com/repos/foo/bar/actions/jobs/1/logs")
        .to_return(status: 404, body: "Not found")

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar"])
      rescue SystemExit
        nil
      end

      assert_match("Downloading CI logs from GitHub", stdout)
      assert_match("Couldn't fetch the CI log. The error was:", stdout)
      assert_match("Error while making a request to Github. Code: 404", stdout)
    end

    def test_rerun_when_a_single_checks_failed
      ci_check_response = {
        total_count: 2,
        check_runs: [
          { "name": "Ruby Test 3.0", id: 1, "conclusion" => "failure", app: { slug: "github-actions" } },
          { "name": "Ruby Test 3.1", id: 2, "conclusion" => "success", app: { slug: "github-actions" } },
        ],
      }

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: ci_check_response)

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/statuses")
        .to_return_json(status: 200, body: "[]")

      stub_request(:get, "https://api.github.com/repos/foo/bar/actions/jobs/1/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/download" })

      stub_request(:get, "https://example.com/download")
        .to_return(status: 200, body: minitest_failure)

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar"])
      end

      assert_match("Automatically selected the CI check Ruby Test 3.0 because it's the only one failing.", stdout)
    end

    def test_rerun_when_multiple_checks_failed
      ci_check_response = {
        total_count: 2,
        check_runs: [
          { "name": "Ruby Test 3.0", id: 1, "conclusion" => "failure", app: { slug: "github-actions" } },
          { "name": "Ruby Test 3.1", id: 2, "conclusion" => "failure", app: { slug: "github-actions" } },
        ],
      }

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: ci_check_response)

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/statuses")
        .to_return_json(status: 200, body: "[]")

      stdout, _ = capture_subprocess_io do
        pid = fork do
          r, w = IO.pipe
          $stdin.reopen(r)
          w.print("Ruby Test 3.0")

          CLI.start(["--commit", "abc", "--repository", "foo/bar"])
        end

        Process.waitpid(pid)
      end

      assert_match("Multiple CI checks failed for this commit. Please choose the one you wish to re-run.", stdout)
      assert_match("You chose: \e[0;3mRuby Test 3.0\e[0m", stdout)
    end

    def test_rerun_when_user_explicitely_pass_a_run_name
      ci_check_response = {
        total_count: 2,
        check_runs: [
          { "name": "Ruby Test 3.0", id: 1, "conclusion" => "failure", app: { slug: "github-actions" } },
          { "name": "Ruby Test 3.1", id: 2, "conclusion" => "failure", app: { slug: "github-actions" } },
        ],
      }

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: ci_check_response)

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/statuses")
        .to_return_json(status: 200, body: "[]")

      stub_request(:get, "https://api.github.com/repos/foo/bar/actions/jobs/2/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/download" })

      stub_request(:get, "https://example.com/download")
        .to_return(status: 200, body: minitest_failure)

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar", "--run-name", "Ruby Test 3.1"])
      end

      assert_match("Your test run is about to start", stdout)
      assert_requested(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
      assert_requested(:get, "https://api.github.com/repos/foo/bar/commits/abc/statuses")
      assert_requested(:get, "https://api.github.com/repos/foo/bar/actions/jobs/2/logs")
      assert_requested(:get, "https://example.com/download")
    end

    def test_rerun_fetch_log_from_circleci
      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: { check_runs: [] })

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/statuses")
        .to_return_json(
          status: 200,
          body: JSON.dump(
            [
              { context: "ci/circleci: ruby-27", target_url: "https://circleci.com/gh/foo/bar/956", state: "failure" },
            ],
          ),
        )

      stub_request(:get, "https://circleci.com/api/v1.1/project/github/foo/bar/956")
        .to_return_json(status: 200, body: read_fixture("circleci/job2.json"))

      stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/1")
        .to_return_json(status: 200, body: read_fixture("circleci/job_setup_output.json"))

      stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/2")
        .to_return_json(status: 200, body: read_fixture("circleci/job_container_output.json"))

      stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/3")
        .to_return_json(status: 200, body: read_fixture("circleci/job_test_output.json"))

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar", "--run-name", "ci/circleci: ruby-27"])
      end

      assert_match("- Number of failings tests:   \e[0;94m1", stdout)
      assert_match("- Test framework detected:    \e[0;94mRSpec", stdout)
      assert_match("Randomized with seed 2668", stdout)

      assert_requested(:get, "https://circleci.com/api/v1.1/project/github/foo/bar/956")
      assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/1")
      assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/2")
      assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/3")
    end

    def test_rerun_fetch_log_from_buildkite
      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: { check_runs: [] })

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/statuses")
        .to_return_json(
          status: 200,
          body: JSON.dump(
            [
              { context: "Ruby tests", target_url: "https://buildkite.com/foo/bar/builds/956", state: "failure" },
            ],
          ),
        )

      stub_request(:get, "https://buildkite.com/foo/bar/builds/956")
        .to_return_json(status: 200, body: read_fixture("buildkite/public_build.json"))

      stub_request(:get, "https://buildkite.com/organizations/katana/pipelines/test/builds/7/jobs/abc/raw_log")
        .to_return(status: 302, headers: { "Location" => "https://example.com/log1" })

      stub_request(:get, "https://buildkite.com/organizations/katana/pipelines/test/builds/7/jobs/def/raw_log")
        .to_return(status: 302, headers: { "Location" => "https://example.com/log2" })

      stub_request(:get, "https://example.com/log1").to_return(status: 200, body: read_fixture("rails.log"))
      stub_request(:get, "https://example.com/log2").to_return(status: 200, body: "def")

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar", "--run-name", "Ruby tests"])
      end

      assert_match("- Number of failings tests:   \e[0;94m9", stdout)
      assert_match("- Test framework detected:    \e[0;94mMinitest", stdout)

      assert_requested(:get, "https://buildkite.com/foo/bar/builds/956")
      assert_requested(:get, "https://buildkite.com/organizations/katana/pipelines/test/builds/7/jobs/abc/raw_log")
      assert_requested(:get, "https://buildkite.com/organizations/katana/pipelines/test/builds/7/jobs/def/raw_log")
      assert_requested(:get, "https://example.com/log1")
      assert_requested(:get, "https://example.com/log2")
    end

    def test_when_log_has_no_failures
      ci_check_response = {
        total_count: 1,
        check_runs: [
          { "name": "Ruby Test 3.0", id: 1, "conclusion" => "failure", app: { slug: "github-actions" } },
        ],
      }

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: ci_check_response)

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/statuses")
        .to_return_json(status: 200, body: "[]")

      stub_request(:get, "https://api.github.com/repos/foo/bar/actions/jobs/1/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/download" })

      stub_request(:get, "https://example.com/download")
        .to_return(status: 200, body: "Running tests with run options --seed 20218:")

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar"])
      rescue SystemExit
        nil
      end

      assert_match("Couldn't detect any \e[0;31;33mMinitest\e[0;31m test failures", stdout)
    end

    def test_github_token_when_token_is_valid
      stub_request(:get, "https://api.github.com/user")
        .to_return_json(status: 200, body: { login: "Bob" })

      stdout, _ = capture_io do
        CLI.start(["github_token", "blabla"])
      end

      assert_match(/Hello.*Bob.*!/, stdout)
      assert_match("Your token is valid!", stdout)
      assert_match("The token has been saved in this file:", stdout)

      expected_config = <<~EOM
        ---
        github:
          token: blabla
      EOM

      assert_equal(expected_config, Configuration::User.instance.config_file.read)
    end

    def test_github_token_when_token_is_invalid
      stub_request(:get, "https://api.github.com/user")
        .to_return_json(status: 401, body: "Requires authentication")

      stdout, _ = capture_io do
        CLI.start(["github_token", "blabla"])
      rescue SystemExit
        nil
      end

      assert_match("Your token doesn't seem to be valid.", stdout)

      expected_config = <<~EOM
        ---
        github:
          token: abc
      EOM

      assert_equal(expected_config, Configuration::User.instance.config_file.read)
    end

    def test_circle_ci_token_when_token_is_valid
      stub_request(:get, "https://circleci.com/api/v1.1/me")
        .to_return_json(status: 200, body: { login: "Bob" })

      stdout, _ = capture_io do
        CLI.start(["circle_ci_token", "blabla"])
      end

      assert_match(/Hello.*Bob.*!/, stdout)
      assert_match("Your token is valid!", stdout)
      assert_match("The token has been saved in this file:", stdout)

      expected_config = <<~EOM
        ---
        github:
          token: abc
        circle_ci:
          token: blabla
      EOM

      assert_equal(expected_config, Configuration::User.instance.config_file.read)
    end

    def test_circle_ci_token_when_token_is_invalid
      stub_request(:get, "https://circleci.com/api/v1.1/me")
        .to_return_json(status: 401, body: "Requires authentication")

      stdout, _ = capture_io do
        CLI.start(["circle_ci_token", "blabla"])
      rescue SystemExit
        nil
      end

      assert_match("Your token doesn't seem to be valid.", stdout)

      expected_config = <<~EOM
        ---
        github:
          token: abc
      EOM

      assert_equal(expected_config, Configuration::User.instance.config_file.read)
    end

    def test_buildkite_token_when_token_is_valid_and_has_all_scopes
      stub_request(:get, "https://api.buildkite.com/v2/access-token")
        .to_return_json(status: 200, body: { scopes: ["read_builds", "read_build_logs"] })

      stdout, _ = capture_io do
        CLI.start(["buildkite_token", "my_token", "catana"])
      rescue SystemExit
        nil
      end

      assert_match("Your token is valid!", stdout)
      assert_match("The token has been saved in this file:", stdout)

      expected_config = <<~EOM
        ---
        github:
          token: abc
        buildkite:
          tokens:
            catana: my_token
      EOM

      assert_equal(expected_config, Configuration::User.instance.config_file.read)
    end

    def test_buildkite_token_downcase_the_org_name
      stub_request(:get, "https://api.buildkite.com/v2/access-token")
        .to_return_json(status: 200, body: { scopes: ["read_builds", "read_build_logs"] })

      stdout, _ = capture_io do
        CLI.start(["buildkite_token", "my_token", "Catana"])
      rescue SystemExit
        nil
      end

      assert_match("Your token is valid!", stdout)
      assert_match("The token has been saved in this file:", stdout)

      expected_config = <<~EOM
        ---
        github:
          token: abc
        buildkite:
          tokens:
            catana: my_token
      EOM

      assert_equal(expected_config, Configuration::User.instance.config_file.read)
    end

    def test_buildkite_token_store_multiple_tokens
      stub_request(:get, "https://api.buildkite.com/v2/access-token")
        .to_return_json(status: 200, body: { scopes: ["read_builds", "read_build_logs"] })

      capture_io do
        CLI.start(["buildkite_token", "my_token", "Catana"])
        CLI.start(["buildkite_token", "another_token", "Some-Org"])
      rescue SystemExit
        nil
      end

      expected_config = <<~EOM
        ---
        github:
          token: abc
        buildkite:
          tokens:
            catana: my_token
            some-org: another_token
      EOM

      assert_equal(expected_config, Configuration::User.instance.config_file.read)
    end

    def test_buildkite_token_when_token_is_valid_but_is_missing_scopes
      stub_request(:get, "https://api.buildkite.com/v2/access-token")
        .to_return_json(status: 200, body: { scopes: ["read_builds"] })

      stdout, _ = capture_io do
        CLI.start(["buildkite_token", "my_token", "catana"])
      rescue SystemExit
        nil
      end

      assert_match("Your token is missing required scope(s): read_build_logs", stdout)

      expected_config = <<~EOM
        ---
        github:
          token: abc
      EOM

      assert_equal(expected_config, Configuration::User.instance.config_file.read)
    end

    def test_buildkite_token_when_token_is_invalid
      stub_request(:get, "https://api.buildkite.com/v2/access-token")
        .to_return_json(status: 401, body: { message: "Authentication required" })

      stdout, _ = capture_io do
        CLI.start(["buildkite_token", "my_token", "catana"])
      rescue SystemExit
        nil
      end

      assert_match("Your token doesn't seem to be valid.", stdout)
      assert_match("Authentication required", stdout)

      expected_config = <<~EOM
        ---
        github:
          token: abc
      EOM

      assert_equal(expected_config, Configuration::User.instance.config_file.read)
    end

    def test_ci_runner_inform_user_of_new_version
      Configuration::User.instance.config_file.delete
      Configuration::User.instance.load!

      verifier = VersionVerifier.new
      verifier.last_checked.delete

      stub_request(:get, "https://api.github.com/repos/Edouard-chin/ci_runner/releases/latest")
        .to_return_json(status: 200, body: { tag_name: "v5.0.0" })

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar"])
      rescue SystemExit
        nil
      end

      assert_match("A newer version of CI Runner is available (5.0.0).", stdout)
      assert_predicate(verifier.last_checked, :exist?)
    end

    private

    def minitest_failure
      <<~EOM
        Run options: --seed 2567

        Failure:
        FooTest#test_one [test/fixtures/tests/foo_test.rb:6]
      EOM
    end
  end
end
