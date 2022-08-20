# frozen_string_literal: true

require_relative "base"
require "uri"
require "open-uri"
require "json"
require "tempfile"

module CIRunner
  module Check
    # A Step object represents a CircleCI step.
    # This Struct has +eql?+ and +hash+ implemented in order to check if two steps are the same and remove
    # the duplicates.
    #
    # Two steps are considered the same if their names are equal and both are successful.
    # The reason this is implemented like this is to avoid downloading too many of the same logfiles.
    #
    # Project on CircleCI can be configured to run in parallel, the number of steps and therefore log output
    # we have to download increases exponentially.
    #
    # As an example, imagine this CircleCI configuration:
    #
    # 'Minitest':
    #   executor: ruby/default
    #   parallelism: 16
    #   steps:
    #     - setup-ruby
    #     - bundle install
    #     - bin/rails test
    #
    # CircleCI will create 48 steps (and 48 log download link). Downloading those 48 log, don't make sense
    # since they will be all similar. Unless they failed, in which case we download the log for that step.
    #
    # @see https://circleci.com/docs/configuration-reference#steps
    Step = Struct.new(:name, :output_url, :failed) do
      # Used in conjuction with +hash+ for unique comparison.
      #
      # @param other [Object]
      #
      # @return [Boolean]
      def eql?(other)
        return false if failed || other.failed

        name == other.name
      end

      # Used for unique comparison.
      #
      # @return [String]
      def hash
        [self.class, name, failed].hash
      end
    end

    # Check class used when a project is configured to run its CI using CircleCI.
    class CircleCI < Base
      attr_reader :url # :private:

      # @param args (See Base#initialize)
      # @param url [String] The html URL pointing to the CircleCI build.
      def initialize(*args, url)
        super(*args)

        @url = url
        @queue = Queue.new
        @tempfile = Tempfile.new
      end

      # Used to tell the user which CI provider we are downloading the log output from.
      #
      # @return [String]
      def provider
        "CircleCI"
      end

      # Download the CI logs for this CI build.
      #
      # CircleCI doesn't have an API to download a single log file for the whole build. Instead, we have
      # to download a log output for each steps. Depending on the number of steps configured on a project, and
      # whether it uses parallelism, the number of log files to download might be quite important.
      #
      # The log for each steps are small in size, so downloading them in parallel to make things much faster.
      #
      # @return [Tempfile]
      def download_log
        client = Client::CircleCI.new
        job = client.job(repository, build_number)
        steps = []

        job["steps"].each do |step|
          step["actions"].each do |parallel|
            next unless parallel["has_output"]

            steps << Step.new(*parallel.values_at("name", "output_url", "failed"))
          end
        end

        steps.uniq!

        steps.each do |step|
          @queue << step
        end

        process_queue

        @tempfile.tap(&:flush)
      end

      # @return [Boolean]
      #
      # @see https://docs.github.com/en/rest/commits/statuses#get-the-combined-status-for-a-specific-reference
      def failed?
        ["error", "failure"].include?(status)
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
      end

      # @param step [Step]
      #
      # @return [void]
      def process(step)
        response = URI.open(step.output_url)
        parsed_response = JSON.parse(response.read)
        log_output = parsed_response.map! { |res| res["message"] }.join

        @tempfile.write(log_output)
      end

      # Dequeue a CircleCI Step from the queue.
      #
      # @return [Step, nil]
      def dequeue
        @queue.pop(true)
      rescue ThreadError
        nil
      end

      # The URL on the commit status will look something like: https://circleci.com/gh/owner/repo/1234?query_string.
      # We want the `1234` which is the builder number.
      #
      # @return [Integer]
      def build_number
        URI(@url.to_s).path.split("/").last
      end
    end
  end
end
