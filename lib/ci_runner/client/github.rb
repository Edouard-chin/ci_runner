# frozen_string_literal: true

require_relative "base"
require "open-uri"

module CIRunner
  module Client
    # A simple client to interact the GitHub API.
    #
    # @example Using the client
    #  Github.new("access_token").me
    class Github < Base
      API_ENDPOINT = "api.github.com"

      # Make an API request to get the authenticated user. Used to verify if the access token
      # the user has stored in its config is valid.
      #
      # @return [Hash] See GitHub documentation.
      #
      # @see https://docs.github.com/en/rest/users/users#get-the-authenticated-user
      def me
        get("/user")
      end

      # Makes an API request to get the CI checks for the +commit+.
      #
      # @param repository [String] The full repository name, including the owner (rails/rails)
      # @param commit [String] The Git commit that has been pushed to GitHub.
      #
      # @return [Hash] See GitHub documentation.
      #
      # @see https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference
      def check_runs(repository, commit)
        get("/repos/#{repository}/commits/#{commit}/check-runs")
      end

      # Makes an API request to get the Commit statuses for the +commit+.
      #
      # @param repository [String] The full repository name, including the owner (rails/rails)
      # @param commit [String] The Git commit that has been pushed to GitHub.
      #
      # @return [Hash] See GitHub documentation.
      #
      # @see https://docs.github.com/en/rest/commits/statuses#list-commit-statuses-for-a-reference
      def commit_statuses(repository, commit)
        get("/repos/#{repository}/commits/#{commit}/statuses")
      end

      # Makes two requests to get the CI log for a check run.
      # The first request returns a 302 containing a Location header poiting to a short lived url to download the log.
      # The second request is to actually download the log.
      #
      # @param repository [String] The full repository name, including the owner (rails/rails)
      # @param check_run_id [Integer] The GitHub ID of the check run.
      #
      # @return [Tempfile, IO] Depending on the size of the response. Quirk of URI.open.
      #
      # @see https://docs.github.com/en/rest/actions/workflow-jobs#download-job-logs-for-a-workflow-run
      def download_log(repository, check_run_id)
        download_url = get("/repos/#{repository}/actions/jobs/#{check_run_id}/logs")

        URI.open(download_url)
      end

      private

      # Add authentication before making the request.
      #
      # @param request [Net::HTTPRequest] A subclass of Net::HTTPRequest.
      #
      # @return [void]
      def authentication(request)
        request.basic_auth("user", @access_token)
      end
    end
  end
end
