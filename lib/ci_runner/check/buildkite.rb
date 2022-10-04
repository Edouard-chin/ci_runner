# frozen_string_literal: true

require_relative "base"
require "uri"

module CIRunner
  module Check
    # Check class used when a project is configured to run its CI using Buildkite.
    class Buildkite < Base
      include ConcurrentDownload

      attr_reader :url # :private:

      # @param args (See Base#initialize)
      # @param url [String] The html URL pointing to the Buildkite build.
      def initialize(*args, url)
        super(*args)

        @url = url
      end

      # Used to tell the user which CI provider we are downloading the log output from.
      #
      # @return [String]
      def provider
        "Buildkite"
      end

      # Download the CI logs for this Buildkite build.
      #
      # The Buildkite API scopes tokens per organizations (token generated for org A can't access
      # resource on org B, even for public resources). This means that for opensource projects using
      # Buildkite, users that are not members of the buildkite org normally can't use CI Runner.
      #
      # To bypass this problem, for builds that are public, CI Runner uses a different API.
      # For private build, CI runner will check if the user had stored a Buildkite token in its config.
      #
      # @return [Tempfile]
      def download_log
        uri = URI(url)
        _, org, pipeline, _, build = uri.path.split("/")
        @client = Client::Buildkite.new

        unless @client.public_build?(org, pipeline, build)
          token = retrieve_token_from_config(org, url)
          @client = Client::AuthenticatedBuildkite.new(token)
        end

        @client.job_logs(org, pipeline, build).each do |log_url|
          @queue << log_url
        end

        process_queue
      end

      private

      # @param url [String]
      #
      # @return [void]
      def process(url)
        @client.reset!
        response = @client.download_log(url)

        @tempfile.write(response.read)
      end

      # Retrieve a Buildkite token from the user confg.
      #
      # @param organization [String] The organization that owns this buildkite build.
      # @param url [String] The FQDN pointing to the buildkite build.
      #
      # @return [String] The token
      #
      # @raise [Error] If no token for that organization exists in the config.
      def retrieve_token_from_config(organization, url)
        token = Configuration::User.instance.buildkite_token(organization.downcase)

        token || raise(Error, <<~EOM)
          Can't get the log output from the Buildkite build #{url} because it requires authentication.

          Please store a Buildkite token scoped to the organization #{organization} and retry.
          See {{command:ci_runner help buildkite_token}}
        EOM
      end
    end
  end
end
