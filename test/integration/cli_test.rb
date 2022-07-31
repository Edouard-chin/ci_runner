# frozen_string_literal: true

require "test_helper"

module CIRunner
  class CLITest < Minitest::Test
    def setup
      UserConfiguration.instance.load!

      super
    end

    def test_rerun_when_no_checks_failed
      klass = Class.new(Minitest::Test) do
        def test_inner
          stub_request(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
            .to_return_json(status: 200, body: { total_count: 0, check_runs: [] })

          CLI.start(%w(--commit abc --repository foo/bar))
        rescue SystemExit
        end
      end

      stdout, _ = capture_io do
        klass.new("test_inner").run
      end

      assert_match("No CI checks failed on this commit.", stdout)
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
        .to_return(status: 200, body: "some_logs")

      stdout, _ = capture_io do
        CLI.start(%w(--commit abc --repository foo/bar))
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
          w.print "Ruby Test 3.0"

          CLI.start(%w(--commit abc --repository foo/bar))
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
        .to_return(status: 200, body: "some_logs")

      stdout, _ = capture_io do
        CLI.start(["--commit", "abc", "--repository", "foo/bar", "--run-name", "Ruby Test 3.1"])
      end

      assert_match("Your test run is about to start", stdout)
      assert_requested(:get, "https://api.github.com/repos/foo/bar/commits/abc/check-runs")
      assert_requested(:get, "https://api.github.com/repos/foo/bar/actions/jobs/2/logs")
      assert_requested(:get, "https://example.com/download")
    end

    def test_github_token_when_token_is_valid
      stub_request(:get, "https://api.github.com/user")
        .to_return_json(status: 200, body: { login: "Bob" })

      stdout, _ = capture_io do
        CLI.start(%w(github_token blabla))
      end

      expected_output = "Hello Bob! Your token has been saved successfully!\n"
      assert_equal(expected_output, stdout)

      expected_config = <<~EOM
        ---
        github:
          token: blabla
      EOM

      assert_equal(expected_config, UserConfiguration.instance.config_file.read)
    end

    def test_github_token_when_token_is_invalid
      stub_request(:get, "https://api.github.com/user")
        .to_return_json(status: 401, body: "Requires authentication")

      _, stderr = capture_io do
        CLI.start(%w(github_token blabla))
      end

      expected = <<~EOM
        Your token doesn't seem to be valid. The response from GitHub was:

        GitHub response: Status: 401. Body:

        Requires authentication
      EOM

      assert_equal(expected, stderr)

      expected_config = <<~EOM
        --- {}
      EOM

      assert_equal(expected_config, UserConfiguration.instance.config_file.read)
    end
  end
end
