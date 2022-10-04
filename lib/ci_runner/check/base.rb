# frozen_string_literal: true

module CIRunner
  module Check
    # Base class for a CI check.
    #
    # @see https://docs.github.com/en/rest/checks/runs#get-a-check-run
    # @see https://docs.github.com/en/rest/commits/statuses#list-commit-statuses-for-a-reference
    class Base
      # @return [String] The full repository name, including the owner (i.e. rails/rails)
      attr_reader :repository

      # @return [String] The Git commit that has been pushed to GitHub and for which we'll retrieve the CI checks.
      attr_reader :commit

      # @return [String] The name of that check. Should be whatever you had set in your CI configuration cile
      attr_reader :name

      # @return [String] The status from the GitHub API for this check. Can be a lot of different values.
      #   See the GitHub API.
      attr_reader :status

      # @param repository (See #repository)
      # @param commit (See #commit)
      # @param name (See #name)
      # @param status (See #status)
      def initialize(repository, commit, name, status)
        @repository = repository
        @commit = commit
        @name = name
        @status = status
      end

      # Subclass have to implement this to download the log(s) output for the build.
      #
      # @raise [NotImplementedError]
      #
      # @return [IO]
      def download_log
        raise(NotImplementedError, "Subclass responsability")
      end

      # Used to tell the user which CI provider we are downloading the log output from.
      #
      # @return [String]
      def provider
        raise(NotImplementedError, "Subclass responsability")
      end

      # @return [Boolean]
      def success?
        @status == "success"
      end

      # @return [Boolean]
      #
      # @see https://docs.github.com/en/rest/commits/statuses#get-the-combined-status-for-a-specific-reference
      def failed?
        ["error", "failure"].include?(status)
      end
    end
  end
end
