# frozen_string_literal: true

require_relative "base"
require "stringio"

module CIRunner
  module Client
    # Client used to retrieve private Resources on buildkite.
    #
    # For public resources, the API can be used but only a limited number of users will be
    # be able to access it as it requires a token scoped for the organization (most users
    # working on opensource project aren't member of the organization they contribute to).
    #
    # @see https://forum.buildkite.community/t/api-access-to-public-builds/1425/2
    # @see Client::Buildkite
    #
    class AuthenticatedBuildkite < Base
      API_ENDPOINT = "api.buildkite.com"

      # Retrieve URLs to download job logs for all steps.
      #
      # @param org [String] The organizatio name.
      # @param pipeline [String] The pipeline name.
      # @param number [Integer] The build number.
      #
      # @return [Array<String>] An array of URLs
      #
      # @see https://buildkite.com/docs/apis/rest-api/builds#get-a-build
      def job_logs(org, pipeline, number)
        build = get("/v2/organizations/#{org}/pipelines/#{pipeline}/builds/#{number}")

        build["jobs"].map do |job|
          job["raw_log_url"]
        end
      end

      # @param url [String] A URL pointing to a log output resource.
      #
      # @return [StringIO]
      #
      # @see https://buildkite.com/docs/apis/rest-api/jobs#get-a-jobs-log-output
      def download_log(url)
        StringIO.new(get(url))
      end

      # Get information about an access token. Used to check if the token has the correct scopes.
      #
      # @see https://buildkite.com/docs/apis/rest-api/access-token
      #
      # @return [Hash] See Buildkite doc
      def access_token
        get("/v2/access-token")
      end

      private

      # Add authentication before making the request.
      #
      # @param request [Net::HTTPRequest] A subclass of Net::HTTPRequest.
      #
      # @return [void]
      def authentication(request)
        request["Authorization"] = "Bearer #{@access_token}"
      end
    end
  end
end
