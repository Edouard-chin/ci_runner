# frozen_string_literal: true

require "test_helper"
require "thor"

module CIRunner
  class LogDownloaderTest < Minitest::Test
    def setup
      @shell = Thor::Shell::Basic.new

      @log_downloader = LogDownloader.new(
        "commit_abcdefghijklm",
        "Edouard/catana",
        "test (3.1.0)",
        @shell,
      )
    end

    def test_fetch_download_the_log
      stub_request(:get, "https://api.github.com/repos/Edouard/catana/commits/commit_abcdefghijklm/check-runs")
        .to_return_json(
          status: 200,
          body: {
            total_count: 1,
            check_runs: [
              {
                name: "test (3.1.0)",
                conclusion: "failure",
                id: 1234,
              }
            ],
          },
        )

      stub_request(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/log" })

      stub_request(:get, "https://example.com/log")
        .to_return(status: 200, body: "abcdef")

      logfile = nil

      @shell.mute do
        logfile = @log_downloader.fetch

        assert_instance_of(Pathname, logfile)
        assert(logfile.exist?)
      end

      assert_requested(:get, "https://api.github.com/repos/Edouard/catana/commits/commit_abcdefghijklm/check-runs")
      assert_requested(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
      assert_requested(:get, "https://example.com/log")
    ensure
      logfile.delete if logfile
    end

    def test_fetch_download_a_bigger_log_open_uri_returns_a_tempfile
      stub_request(:get, "https://api.github.com/repos/Edouard/catana/commits/commit_abcdefghijklm/check-runs")
        .to_return_json(
          status: 200,
          body: {
            total_count: 1,
            check_runs: [
              {
                name: "test (3.1.0)",
                conclusion: "failure",
                id: 1234,
              }
            ],
          },
        )

      stub_request(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/log" })

      stub_request(:get, "https://example.com/log")
        .to_return(status: 200, body: "a" * 100000)

      logfile = nil

      @shell.mute do
        logfile = @log_downloader.fetch

        assert_instance_of(Pathname, logfile)
        assert(logfile.exist?)
      end

      assert_requested(:get, "https://api.github.com/repos/Edouard/catana/commits/commit_abcdefghijklm/check-runs")
      assert_requested(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
      assert_requested(:get, "https://example.com/log")
    ensure
      logfile.delete if logfile
    end

    def test_fetch_get_the_cached_log
      stub_request(:get, "https://api.github.com/repos/Edouard/catana/commits/commit_abcdefghijklm/check-runs")
        .to_return_json(
          status: 200,
          body: {
            total_count: 1,
            check_runs: [
              {
                name: "test (3.1.0)",
                conclusion: "failure",
                id: 1234,
              }
            ],
          },
        )

      stub_request(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/log" })

      stub_request(:get, "https://example.com/log")
        .to_return(status: 200, body: "abcdef")

      logfile = nil

      @shell.mute do
        logfile = @log_downloader.fetch

        assert_instance_of(Pathname, logfile)
        assert(logfile.exist?)
      end

      @shell.mute do
        @log_downloader.fetch
      end

      assert_requested(:get, "https://api.github.com/repos/Edouard/catana/commits/commit_abcdefghijklm/check-runs", times: 1)
      assert_requested(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs", times: 1)
      assert_requested(:get, "https://example.com/log", times: 1)
    ensure
      logfile.delete if logfile
    end

    def test_fetch_does_not_download_log_if_no_checks_are_failing
      stub_request(:get, "https://api.github.com/repos/Edouard/catana/commits/commit_abcdefghijklm/check-runs")
        .to_return_json(
          status: 200,
          body: {
            total_count: 1,
            check_runs: [
              {
                name: "test (3.1.0)",
                conclusion: "success",
                id: 1234,
              }
            ],
          },
        )

      err = assert_raises(Error) do
        @log_downloader.fetch
      end

      expected = <<~EOM
        No CI check failed on this commit. There will be no failing tests to run.
        Checks on this commit:

        \u{1f7e2} test (3.1.0)
      EOM

      assert_equal(expected, err.message)
    end

    def test_fetch_does_not_download_log_if_no_checks_exist_with_the_given_name
      stub_request(:get, "https://api.github.com/repos/Edouard/catana/commits/commit_abcdefghijklm/check-runs")
        .to_return_json(
          status: 200,
          body: {
            total_count: 1,
            check_runs: [
              {
                name: "CLA",
                conclusion: "failure",
                id: 1234,
              }
            ],
          },
        )

      err = assert_raises(Error) do
        @log_downloader.fetch
      end

      expected = <<~EOM
        Couldn't find a failed CI Check run with the name 'test (3.1.0)'.

        Failed CI check names:

        CLA
      EOM

      assert_equal(expected, err.message)
    end
  end
end
