# frozen_string_literal: true

require "test_helper"
require "json"

module CIRunner
  module Check
    class BuildkiteTest < Minitest::Test
      def setup
        @check = Buildkite.new(
          "owner/repo",
          "abcdef",
          "Ruby Tests",
          "failure",
          "https://buildkite.com/katana/test/builds/1",
        )

        Configuration::User.instance.load!
      end

      def test_download_log_when_the_pipeline_is_public
        stub_request(:get, "https://buildkite.com/katana/test/builds/1")
          .to_return_json(status: 200, body: read_fixture("buildkite/public_build.json"))

        stub_request(:get, "https://buildkite.com/organizations/katana/pipelines/test/builds/7/jobs/abc/raw_log")
          .to_return(status: 302, headers: { "Location" => "https://example.com/log1" })

        stub_request(:get, "https://buildkite.com/organizations/katana/pipelines/test/builds/7/jobs/def/raw_log")
          .to_return(status: 302, headers: { "Location" => "https://example.com/log2" })

        stub_request(:get, "https://example.com/log1").to_return(status: 200, body: "abc")
        stub_request(:get, "https://example.com/log2").to_return(status: 200, body: "def")

        file = @check.download_log
        file.rewind
        file_content = file.read

        assert_match("abc", file_content)
        assert_match("def", file_content)
        assert_requested(:get, "https://buildkite.com/katana/test/builds/1")
        assert_requested(:get, "https://buildkite.com/organizations/katana/pipelines/test/builds/7/jobs/abc/raw_log")
        assert_requested(:get, "https://example.com/log1")
        assert_requested(:get, "https://example.com/log2")
      end

      def test_download_log_when_the_pipeline_is_private
        Configuration::User.instance.save_buildkite_token("my_token", "katana")

        stub_request(:get, "https://buildkite.com/katana/test/builds/1")
          .to_return_json(status: 403)

        stub_request(:get, "https://api.buildkite.com/v2/organizations/katana/pipelines/test/builds/1")
          .to_return_json(status: 200, body: read_fixture("buildkite/private_build.json"))

        stub_request(:get, "https://api.buildkite.com/v2/organizations/katana/pipelines/private-build/builds/1/jobs/abc/log.txt")
          .to_return(status: 200, body: "abc")

        file = @check.download_log
        file.rewind
        file_content = file.read

        assert_match("abc", file_content)

        assert_requested(:get, "https://buildkite.com/katana/test/builds/1")
        assert_requested(:get, "https://api.buildkite.com/v2/organizations/katana/pipelines/test/builds/1") do |req|
          assert_equal("Bearer my_token", req.headers["Authorization"])
        end
        assert_requested(:get, "https://api.buildkite.com/v2/organizations/katana/pipelines/private-build/builds/1/jobs/abc/log.txt")
      end

      def test_download_log_when_the_pipeline_is_private_but_no_token_have_been_stored
        stub_request(:get, "https://buildkite.com/katana/test/builds/1")
          .to_return_json(status: 403)

        error = assert_raises(Error) do
          @check.download_log
        end

        assert_equal(<<~EOM, error.message)
          Can't get the log output from the Buildkite build https://buildkite.com/katana/test/builds/1 because it requires authentication.

          Please store a Buildkite token scoped to the organization katana and retry.
          See {{command:ci_runner help buildkite_token}}
        EOM
        assert_requested(:get, "https://buildkite.com/katana/test/builds/1")
      end
    end
  end
end
