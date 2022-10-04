# frozen_string_literal: true

require "test_helper"

module CIRunner
  module Client
    class BuildkiteTest < Minitest::Test
      def test_public_build_is_true_when_build_is_public
        stub_request(:get, "https://buildkite.com/foo/bar/builds/1")
          .to_return_json(status: 200, body: { jobs: [] })

        client = Buildkite.new

        assert(client.public_build?("foo", "bar", 1))
      end

      def test_public_build_is_false_when_build_is_private
        stub_request(:get, "https://buildkite.com/foo/bar/builds/1")
          .to_return_json(status: 403)

        client = Buildkite.new

        refute(client.public_build?("foo", "bar", 1))
      end

      def test_public_build_raises_when_error_returned_is_not_a_403
        stub_request(:get, "https://buildkite.com/foo/bar/builds/1")
          .to_return_json(status: 401)

        client = Buildkite.new

        assert_raises(Error) do
          client.public_build?("foo", "bar", 1)
        end
      end

      def test_job_logs_return_a_list_of_url_paths
        stub_request(:get, "https://buildkite.com/foo/bar/builds/1")
          .to_return_json(
            status: 200,
            body: {
              jobs: [
                { base_path: "/foo/bar/123" },
                { base_path: "/foo/bar/456" },
              ],
            },
          )

        client = Buildkite.new

        paths = client.job_logs("foo", "bar", 1)
        assert_equal(["/foo/bar/123/raw_log", "/foo/bar/456/raw_log"], paths)
      end

      def test_download_log
        stub_request(:get, "https://buildkite.com/foo/bar/123/raw_log")
          .to_return(status: 302, headers: { "Location" => "https://example.com/log" })

        stub_request(:get, "https://example.com/log")

        Buildkite.new.download_log("/foo/bar/123/raw_log")

        assert_requested(:get, "https://buildkite.com/foo/bar/123/raw_log")
        assert_requested(:get, "https://example.com/log")
      end
    end
  end
end
