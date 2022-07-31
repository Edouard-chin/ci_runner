# frozen_string_literal: true

require "net/http"
require "openssl"
require "json"
require "open-uri"

module CIRunner
  class GithubClient
    Error = Class.new(StandardError)

    def self.default_client
      Net::HTTP.new("api.github.com", 443).tap do |http|
        http.use_ssl = true
        http.read_timeout = 3
        http.write_timeout = 3
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end
    end

    def initialize(access_token, client = self.class.default_client)
      @access_token = access_token
      @client = client
    end

    def me
      get("/user")
    end

    def check_runs(repository, commit)
      get("/repos/#{repository}/commits/#{commit}/check-runs")
    # rescue Error
    #   ::CLI::UI.puts(<<~EOM)
    #     Couldn't retrieve the CI checks for the commit: #{commit}.

    #     Are you sure it was pushed to GitHub ?
    #   EOM

    #   ::CLI::UI::Spinner::TASK_FAILED
    end

    def download_log(repository, check_run_id)
      download_url = get("/repos/#{repository}/actions/jobs/#{check_run_id}/logs")

      URI.open(download_url)
    end

    private

    def get(path)
      request(Net::HTTP::Get, path)
    end

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
