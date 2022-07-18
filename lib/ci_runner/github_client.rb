# frozen_string_literal: true

require "net/http"
require "openssl"
require "json"
require "open-uri"
require "byebug"

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

    def check_runs(commit)
      get("/repos/Edouard-chin/github_diff_parser/commits/#{commit}/check-runs")
    rescue Error
      raise(Error, <<~EOM)
        Couldn't retrieve the CI checks for the commit: #{commit}.

        Are you sure it was pushed to GitHub ?
      EOM
    end

    def download_log(check_run_id)
      download_url = get("/repos/Edouard-chin/github_diff_parser/actions/jobs/#{check_run_id}/logs")

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
      when 422
        raise(Error)
      else
        raise(response.body)
      end
    end
  end
end
