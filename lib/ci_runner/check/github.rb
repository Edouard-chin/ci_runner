# frozen_string_literal: true

require_relative "base"

module CIRunner
  module Check
    # Check class used when a project is configured to run its CI using GitHub actions.
    #
    # @see https://docs.github.com/en/rest/actions/workflow-jobs
    class Github < Base
      attr_reader :id # :private:

      # @param args (See Base#initialize)
      # @param id [Integer] The ID of this check.
      def initialize(*args, id)
        super(*args)

        @id = id
      end

      # Used to tell the user which CI provider we are downloading the log output from.
      #
      # @return [String]
      def provider
        "GitHub"
      end

      # Download the log output for thig GitHub build.
      #
      # @return (See Client::Github#download_log)
      #
      # @see https://docs.github.com/en/rest/actions/workflow-jobs#download-job-logs-for-a-workflow-run
      def download_log
        github_client = Client::Github.new(Configuration::User.instance.github_token)

        github_client.download_log(@repository, @id)
      end
    end
  end
end
