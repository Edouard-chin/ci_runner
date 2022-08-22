# frozen_string_literal: true

require "test_helper"

module CIRunner
  module Client
    class CircleCITest < Minitest::Test
      def test_request_without_authentication
        stub_request(:get, "https://circleci.com/api/v1.1/project/github/catanacorp/catana/123")
          .to_return_json(status: 200, body: {})

        client = CircleCI.new
        job = client.job("catanacorp/catana", 123)

        assert_equal({}, job)
        assert_requested(:get, "https://circleci.com/api/v1.1/project/github/catanacorp/catana/123") do |req|
          refute(req.headers.key?("Authorization"))
        end
      end

      def test_request_with_authentication
        token = "abcdef"
        encoded_access_token = Base64.strict_encode64("#{token}:")

        stub_request(:get, "https://circleci.com/api/v1.1/project/github/catanacorp/catana/123")
          .with(headers: { "Authorization" => "Basic #{encoded_access_token}" })
          .to_return_json(status: 200, body: {})

        client = CircleCI.new(token)
        job = client.job("catanacorp/catana", 123)

        assert_equal({}, job)
        assert_requested(:get, "https://circleci.com/api/v1.1/project/github/catanacorp/catana/123")
      end

      def test_job_returns_a_404_and_no_token_is_set
        stub_request(:get, "https://circleci.com/api/v1.1/project/github/catanacorp/catana/123")
          .to_return_json(status: 404, body: { message: "Not Found" })

        error = assert_raises(Client::Error) do
          CircleCI.new.job("catanacorp/catana", 123)
        end

        assert_equal(<<~EOM.rstrip, error.message)
          404 while trying to fetch the CircleCI build.

          {{warning:Please save a CircleCI token in your configuration.}}
          {{command:ci_runner help circle_ci_token}}
        EOM

        assert_equal(404, error.error_code)
      end

      def test_job_returns_a_404_and_a_token_is_set
        stub_request(:get, "https://circleci.com/api/v1.1/project/github/catanacorp/catana/123")
          .to_return_json(status: 404, body: { message: "Not Found" })

        error = assert_raises(Client::Error) do
          CircleCI.new("token").job("catanacorp/catana", 123)
        end

        assert_equal(<<~EOM.rstrip, error.message)
          Error while making a request to CircleCI. Code: 404

          The response was: {"message":"Not Found"}
        EOM

        assert_equal(404, error.error_code)
      end

      def test_job_returns_a_422_and_no_token_is_set
        stub_request(:get, "https://circleci.com/api/v1.1/project/github/catanacorp/catana/123")
          .to_return_json(status: 422, body: { message: "Unauthorized" })

        error = assert_raises(Client::Error) do
          CircleCI.new.job("catanacorp/catana", 123)
        end

        assert_equal(<<~EOM.rstrip, error.message)
          Error while making a request to CircleCI. Code: 422

          The response was: {"message":"Unauthorized"}
        EOM

        assert_equal(422, error.error_code)
      end
    end
  end
end
