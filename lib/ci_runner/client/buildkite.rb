# frozen_string_literal: true

require_relative "base"
require "open-uri"

module CIRunner
  module Client
    # Client used for public Buildkite resources.
    # Allow any users to download log output for builds that are in organizations they
    # are not a member of.
    #
    # This client doesn't use the official buildkite API. The data returned are not exactly the same.
    class Buildkite < Base
      API_ENDPOINT = "buildkite.com"

      # Check if the build is public and can be accessed without authentication.
      #
      # @param org [String] The organizatio name.
      # @param pipeline [String] The pipeline name.
      # @param number [Integer] The build number.
      #
      # @return [Boolean]
      def public_build?(org, pipeline, build_number)
        job_logs(org, pipeline, build_number)

        true
      rescue Error => e
        return false if e.error_code == 403

        raise(e)
      end

      # Retrieve URL paths to download job logs for all steps.
      #
      # @param org [String] The organizatio name.
      # @param pipeline [String] The pipeline name.
      # @param number [Integer] The build number.
      #
      # @return [Array<String>] An array of URL paths
      def job_logs(org, pipeline, build_number)
        @build ||= get("/#{org}/#{pipeline}/builds/#{build_number}")

        @build["jobs"].map do |job|
          job["base_path"] + "/raw_log"
        end
      end

      # Download raw log output for a job.
      #
      # @param path [String] A URL path
      #
      # @return [Tempfile, IO] Depending on the size of the response. Quirk of URI.open.
      def download_log(path)
        redirection_url = get(path)

        URI.open(redirection_url)
      end
    end
  end
end
