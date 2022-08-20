# frozen_string_literal: true

require_relative "base"

module CIRunner
  module Client
    class CircleCI < Base
      API_ENDPOINT = "circleci.com"

      # @param repository [String] The full repository name including the owner (rails/rails).
      # @param build_number [Integer] The CircleCI build number.
      #
      # @see https://circleci.com/docs/api/v1/index.html#single-job
      def job(repository, build_number)
        get("/api/v1.1/project/github/#{repository}/#{build_number}")
      end
    end
  end
end
