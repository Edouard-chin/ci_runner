# frozen_string_literal: true

require "test_helper"

module CIRunner
  class LogDownloaderTest < Minitest::Test
    def setup
      super

      @log_downloader = LogDownloader.new(
        Check::Github.new("Edouard/catana", "commit_sha", "Ruby 3.1.2 Run", "failure", 1234)
      )
    end

    def test_fetch_download_the_log
      stub_request(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/log" })
      stub_request(:get, "https://example.com/log")
        .to_return(status: 200, body: "abcdef")

      logfile = nil

      out, _ = capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          logfile = @log_downloader.fetch
        end
      end

      assert_match("Downloading CI logs from GitHub", out)
      assert_instance_of(Pathname, logfile)
      assert(logfile.exist?)
      assert_match("Edouard/catana/log-commit_sha-Ruby 3.1.2 Run.log", logfile.to_s)

      assert_requested(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
      assert_requested(:get, "https://example.com/log")
    ensure
      logfile&.delete
    end

    def test_fetch_download_a_bigger_log_open_uri_returns_a_tempfile
      stub_request(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/log" })
      stub_request(:get, "https://example.com/log")
        .to_return(status: 200, body: "a" * 100000)

      logfile = nil

      out, _ = capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          logfile = @log_downloader.fetch
        end
      end

      assert_match("Downloading CI logs from GitHub", out)
      assert_instance_of(Pathname, logfile)
      assert(logfile.exist?)
      assert_match("Edouard/catana/log-commit_sha-Ruby 3.1.2 Run.log", logfile.to_s)

      assert_requested(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
      assert_requested(:get, "https://example.com/log")
    ensure
      logfile&.delete
    end

    def test_fetch_get_the_cached_log
      stub_request(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
        .to_return(status: 302, headers: { "Location" => "https://example.com/log" })
      stub_request(:get, "https://example.com/log")
        .to_return(status: 200, body: "abcdef")

      logfile = nil

      out, _ = capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          logfile = @log_downloader.fetch
        end
      end

      assert_match("Downloading CI logs from GitHub", out)
      assert_instance_of(Pathname, logfile)
      assert(logfile.exist?)
      assert_match("Edouard/catana/log-commit_sha-Ruby 3.1.2 Run.log", logfile.to_s)

      ::CLI::UI::StdoutRouter.with_enabled do
        @log_downloader.fetch
      end

      assert_requested(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs", times: 1)
      assert_requested(:get, "https://example.com/log", times: 1)
    ensure
      logfile&.delete
    end

    def test_fetch_fails_to_retrieve_log
      stub_request(:get, "https://api.github.com/repos/Edouard/catana/actions/jobs/1234/logs")
        .to_return(status: 404, body: "Not found")

      out, _ = capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          @log_downloader.fetch { |error| puts "Oh no! #{error.message}" }
        end
      end

      assert_match("Downloading CI logs from GitHub", out)
      assert_match("Oh no! GitHub response: Status: 404. Body:", out)
    end
  end
end
