# frozen_string_literal: true

require "net/http"
require "openssl"
require "json"
require "open-uri"

module CIRunner
  # A simple client to interact the GitHub API.
  #
  # @example Using the client
  #  GithubClient.new("access_token").me
  class GithubClient
    Error = Class.new(StandardError)

    # @return [Net::HTTP] An instance of Net:HTTP configured to make requests to the GitHub API endpoint.
    def self.default_client
      Net::HTTP.new("api.github.com", 443).tap do |http|
        http.use_ssl = true
        http.read_timeout = 3
        http.write_timeout = 3
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
    end

    # @param access_token [String] The access token with "repo" scope.
    # @param client [Net::HTTP]
    def initialize(access_token, client = self.class.default_client)
      @access_token = access_token
      @client = client
    end

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

      URI.open(download_url) # rubocop:disable Security/Open
    end

    private

    # Perform an authenticated GET request.
    #
    # @param path [String] The resource to access.
    #
    # @return (See #request)
    def get(path)
      request(Net::HTTP::Get, path)
    end

    # Perform an authenticated request.
    #
    # @param verb_class [Net::HTTPRequest] A subclass of Net::HTTPRequest.
    # @param path [String] The resource to access.
    #
    # @return [Hash, String] A decoded JSON response or a String pointing to the Location redirection.
    def request(verb_class, path)
      req = verb_class.new(path)
      req["Accept"] = "application/vnd.github+json"
      req.basic_auth("user", @access_token)

      response = @client.request(req)

      case response.code.to_i
      when 200..204
        response.content_type == "application/json" ? JSON.parse(response.body) : response.body
      when 302
        response["Location"]
      else
        raise(Error, "GitHub response: Status: #{response.code}. Body:\n\n#{response.body}")
      end
    end
  end
end
