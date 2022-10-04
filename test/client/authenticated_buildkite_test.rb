# frozen_string_literal: true

require "test_helper"

module CIRunner
  module Client
    class AuthenticatedBuildkiteTest < Minitest::Test
      def setup
        super

        @client = AuthenticatedBuildkite.new("my_token")
      end

      def test_job_logs_return_a_list_of_urls
        stub_request(:get, "https://api.buildkite.com/v2/organizations/foo/pipelines/bar/builds/1")
          .to_return_json(
            status: 200,
            body: {
              jobs: [
                { raw_log_url: "https://api.buildkite.com/v2/organizations/foo/pipelines/bar/123/log.txt" },
                { raw_log_url: "https://api.buildkite.com/v2/organizations/foo/pipelines/bar/456/log.txt" },
              ],
            },
          )

        urls = @client.job_logs("foo", "bar", 1)
        assert_equal(
          [
            "https://api.buildkite.com/v2/organizations/foo/pipelines/bar/123/log.txt",
            "https://api.buildkite.com/v2/organizations/foo/pipelines/bar/456/log.txt",
          ],
          urls,
        )

        assert_requested(:get, "https://api.buildkite.com/v2/organizations/foo/pipelines/bar/builds/1")
      end

      def test_download_log
        stub_request(:get, "https://api.buildkite.com/v2/organizations/foo/pipelines/bar/123/log.txt")
          .to_return(status: 200, body: "def")

        content = @client.download_log("https://api.buildkite.com/v2/organizations/foo/pipelines/bar/123/log.txt")

        assert_instance_of(StringIO, content)
        assert_equal("def", content.read)
        assert_requested(:get, "https://api.buildkite.com/v2/organizations/foo/pipelines/bar/123/log.txt")
      end

      def test_authenticates_using_a_bearer_token
        stub_request(:get, "https://api.buildkite.com/v2/organizations/foo/pipelines/bar/123/log.txt")

        @client.download_log("https://api.buildkite.com/v2/organizations/foo/pipelines/bar/123/log.txt")

        assert_requested(:get, "https://api.buildkite.com/v2/organizations/foo/pipelines/bar/123/log.txt") do |req|
          assert_equal("Bearer my_token", req.headers["Authorization"])
        end
      end
    end
  end
end
