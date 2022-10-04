# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"

module CIRunner
  module Client
    class Base
      # @return [Net::HTTP] An instance of Net:HTTP configured to make requests to the GitHub API endpoint.
      def self.default_client
        Net::HTTP.new(self::API_ENDPOINT, 443).tap do |http|
          http.use_ssl = true
          http.read_timeout = 3
          http.write_timeout = 3
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
      end

      # @param access_token [String] The access token with "repo" scope.
      # @param client [Net::HTTP]
      def initialize(access_token = nil, client = self.class.default_client)
        @access_token = access_token
        @client = client
      end

      # Set a new Client object.
      # NET::HTTP is not threadsafe so each time we need to make requests concurrently we need to use a new client.
      #
      # @return [void]
      def reset!
        @client = self.class.default_client
      end

      private

      # Add authentication before making the request.
      #
      # @param request [Net::HTTPRequest] A subclass of Net::HTTPRequest.
      #
      # @return [void]
      def authentication(request)
      end

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
        req["Accept"] = "application/json"
        authentication(req)

        response = @client.request(req)

        case response.code.to_i
        when 200..204
          response.content_type == "application/json" ? JSON.parse(response.body) : response.body
        when 302
          response["Location"]
        else
          raise(Error.new(response.code, response.body, self.class.name.split("::").last))
        end
      end
    end
  end
end
