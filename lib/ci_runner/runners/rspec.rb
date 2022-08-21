# frozen_string_literal: true

require_relative "base"

module CIRunner
  module Runners
    class RSpec < Base
      SEED_REGEX = /Randomized with seed[[:blank:]]*(\d+)/
      BUFFER_STARTS = /(Finished in|Failed examples)/

      # @param ci_log [String] The CI log output
      #
      # @return [Boolean] Whether this runner detects (and therefore can handle) Minitest from the log output.
      def self.match?(log)
        command = /bundle exec rspec/
        summary = /Failed examples:/

        Regexp.union(command, summary).match?(log)
      end

      # @return [String] See Runners::Base#report
      def name
        "RSpec"
      end

      def start!
        super

        flags = failures.map { |failure| "--example '#{failure.test_name}'" }.join(" ")
        flags << " --seed #{seed}" if seed

        code = <<~EOM
          require 'rspec/core/rake_task'

          RSpec::Core::RakeTask.new('__ci_runner_test') do |task|
            task.pattern = #{failures.map(&:path)}
            task.rspec_opts = "#{flags}"
            task.verbose = false
          end

          Rake::Task[:__ci_runner_test].invoke
        EOM

        dir = Dir.mktmpdir
        rakefile_path = File.expand_path("Rakefile", dir)

        File.write(rakefile_path, code)

        env = {}
        env["RUBY"] = ruby_path.to_s if ruby_path&.exist?
        env["BUNDLE_GEMFILE"] = gemfile_path.to_s if gemfile_path&.exist?

        execute_within_frame(env, "bundle exec ruby #{rakefile_path}")
      end

      private

      def process_buffer
        failure_regex = /rspec[[:blank:]]*(?<file_path>.*?):\d+[[:blank:]]*#[[:blank:]]*(?<test_name>.*)/

        @buffer.each_line do |line|
          line.match(failure_regex) do |match_data|
            @failures << TestFailure.new(nil, match_data[:test_name].rstrip, match_data[:file_path])
          end
        end
      end
    end
  end
end
