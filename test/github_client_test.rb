# frozen_string_literal: true

require "test_helper"

module CIRunner
  class GithubClientTest < Minitest::Test
    def setup
      access_token = "token"
      @encoded_access_token = Base64.strict_encode64("user:#{access_token}")
      @client = GithubClient.new(access_token)

      super
    end

    def test_me_retrieve_the_user
      stub_request(:get, "https://api.github.com/user")
        .with(headers: { "Authorization" => "Basic #{@encoded_access_token}" })

      @client.me

      assert_requested(:get, "https://api.github.com/user")
    end

    def test_check_runs_retrieve_ci_checks
      stub_request(:get, "https://api.github.com/repos/catanacorp/ci_runner/commits/some_commit/check-runs")
        .with(headers: { "Authorization" => "Basic #{@encoded_access_token}" })

      @client.check_runs("catanacorp/ci_runner", "some_commit")

      assert_requested(:get, "https://api.github.com/repos/catanacorp/ci_runner/commits/some_commit/check-runs")
    end

    def test_download_log_download_log_from_a_check
      stub_request(:get, "https://api.github.com/repos/catanacorp/ci_runner/actions/jobs/123/logs")
        .with(headers: { "Authorization" => "Basic #{@encoded_access_token}" })
        .to_return(status: 302, headers: { "Location" => "https://example.com/download" })
      stub_request(:get, "https://example.com/download")

      @client.download_log("catanacorp/ci_runner", 123)

      assert_requested(:get, "https://api.github.com/repos/catanacorp/ci_runner/actions/jobs/123/logs")
      assert_requested(:get, "https://example.com/download")
    end

    def test_response_is_json_decoded
      stub_request(:get, "https://api.github.com/user")
        .to_return_json(status: 200, body: { name: "edouard" })

      user = @client.me

      assert_equal({ "name" => "edouard" }, user)
      assert_requested(:get, "https://api.github.com/user")
    end

    def test_raises_when_response_is_not_in_the_200_204_range
      stub_request(:get, "https://api.github.com/user")
        .to_return(status: 422, body: '{"message":"Unprocessable"}')

      error = assert_raises(GithubClient::Error) do
        @client.me
      end

      assert_equal(<<~EOM.rstrip, error.message)
        GitHub response: Status: 422. Body:

        {"message":"Unprocessable"}
      EOM
    end
  end
end
