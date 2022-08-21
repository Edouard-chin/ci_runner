# frozen_string_literal: true

require "test_helper"

module CIRunner
  class CLITest < Minitest::Test
    def setup
      Configuration::User.instance.load!
      Configuration::User.instance.save_github_token("abc")

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

      assert_match("GitHub token needs to be saved into your configuration before being able to use CI Runner", stdout)
      assert_match(/mHave a look at the .*ci_runner help github_token.* command./, stdout)
    end

    def test_rerun_when_no_checks_failed
      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: { total_count: 0, check_runs: [] })

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
          { "name": "Ruby Test 3.0", id: 1, "conclusion" => "failure" },
          { "name": "Ruby Test 3.1", id: 2, "conclusion" => "success" },
        ],
      }

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: ci_check_response)
      stub_request(:get, "https://api.github.com/repos/foo/bar/actions/jobs/1/logs")
        .to_return(status: 404, body: "Not found")

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar"])
      rescue SystemExit
        nil
      end

      assert_match("Downloading CI logs from GitHub", stdout)
      assert_match("Couldn't fetch the CI log. The response from GitHub was:", stdout)
      assert_match("GitHub response: Status: 404. Body:", stdout)
    end

    def test_rerun_when_a_single_checks_failed
      ci_check_response = {
        total_count: 2,
        check_runs: [
          { "name": "Ruby Test 3.0", id: 1, "conclusion" => "failure" },
          { "name": "Ruby Test 3.1", id: 2, "conclusion" => "success" },
        ],
      }

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: ci_check_response)
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
          { "name": "Ruby Test 3.0", id: 1, "conclusion" => "failure" },
          { "name": "Ruby Test 3.1", id: 2, "conclusion" => "failure" },
        ],
      }

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: ci_check_response)

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
          { "name": "Ruby Test 3.0", id: 1, "conclusion" => "failure" },
          { "name": "Ruby Test 3.1", id: 2, "conclusion" => "failure" },
        ],
      }

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: ci_check_response)

      stub_request(:get, "https://api.github.com/repos/foo/bar/actions/jobs/2/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/download" })

      stub_request(:get, "https://example.com/download")
        .to_return(status: 200, body: minitest_failure)

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar", "--run-name", "Ruby Test 3.1"])
      end

      assert_match("Your test run is about to start", stdout)
      assert_requested(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
      assert_requested(:get, "https://api.github.com/repos/foo/bar/actions/jobs/2/logs")
      assert_requested(:get, "https://example.com/download")
    end

    def test_when_log_has_no_failures
      ci_check_response = {
        total_count: 1,
        check_runs: [
          { "name": "Ruby Test 3.0", id: 1, "conclusion" => "failure" },
        ],
      }

      stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
        .to_return_json(status: 200, body: ci_check_response)
      stub_request(:get, "https://api.github.com/repos/foo/bar/actions/jobs/1/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/download" })
      stub_request(:get, "https://example.com/download")
        .to_return(status: 200, body: "minitest")

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
