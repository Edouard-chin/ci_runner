# frozen_string_literal: true

require_relative "base"

module CIRunner
  module Client
    class CircleCI < Base
      API_ENDPOINT = "circleci.com"

      # Make an API request to get the authenticated user. Used to verify if the access token
      # the user has stored in its config is valid.
      #
      # @return [Hash] See Circle CI documentation.
      #
      # @see https://circleci.com/docs/api/v1/index.html#user
      def me
        get("/api/v1.1/me")
      end

      # @param repository [String] The full repository name including the owner (rails/rails).
      # @param build_number [Integer] The CircleCI build number.
      #
      # @see https://circleci.com/docs/api/v1/index.html#single-job
      def job(repository, build_number)
        get("/api/v1.1/project/github/#{repository}/#{build_number}")
      rescue Error => e
        reraise_with_reason(e)
      end

      private

      # Add authentication before making the request.
      #
      # @param request [Net::HTTPRequest] A subclass of Net::HTTPRequest.
      #
      # @return [void]
      def authentication(request)
        request.basic_auth(@access_token, "") if @access_token
      end

      # @param error [Client::Error]
      #
      # @raise [Client::Error] A better error message in case of a 404.
      def reraise_with_reason(error)
        if @access_token.nil? && error.error_code == 404
          raise(error, <<~EOM.rstrip)
            404 while trying to fetch the CircleCI build.

            {{warning:Please save a CircleCI token in your configuration.}}
            {{command:ci_runner help circle_ci_token}}
          EOM
        else
          raise(error)
        end
      end
    end
  end
end
