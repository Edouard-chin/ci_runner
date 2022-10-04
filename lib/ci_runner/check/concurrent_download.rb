# frozen_string_literal: true

require "tempfile"

module CIRunner
  module Check
    # Module used to dowload multiple logfiles in parallel.
    #
    # Some CI providers doesn't have an API to download a single log file for the whole
    # build, and instead one log file is produced per step. CI Runner needs to download
    # the logfile of all steps in the build in order to rerun all test that failed.
    module ConcurrentDownload
      def initialize(...)
        @queue = Queue.new
        @tempfile = Tempfile.new

        super(...)
      end

      private

      # Implement a queuing system in order to download log files in parallel.
      #
      # @return [void]
      def process_queue
        max_threads = 6
        threads = []

        max_threads.times do
          threads << Thread.new do
            while (element = dequeue)
              process(element)
            end
          end
        end

        threads.each(&:join)

        @tempfile.tap(&:flush)
      end

      # Process item in the queue.
      def process
        raise(NotImplementedError)
      end

      # Dequeue a CircleCI Step from the queue.
      #
      # @return [Step, nil]
      def dequeue
        @queue.pop(true)
      rescue ThreadError
        nil
      end
    end
  end
end
