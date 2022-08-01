# frozen_string_literal: true

require_relative "base"
require "drb/drb"
require "tempfile"

module CIRunner
  module Runners
    class MinitestRunner < Base
      SEED_REGEX = Regexp.union(
        /Run options:.*?--seed\s+(\d+)/, # Default Minitest Statistics Repoter
        /Running tests with run options.*--seed\s+(\d+)/, # MinitestReporters BaseReporter
        /Started with run options.*--seed\s+(\d+)/, # MinitestReporters ProgressReporter
      )
      BUFFER_STARTS = /(Failure|Error):\s*\Z/

      def self.match?(ci_log)
        default_reporter = /(Finished in) \d+\.\d{6}s, \d+\.\d{4} runs\/s, \d+\.\d{4} assertions\/s\./

        Regexp.union(default_reporter, SEED_REGEX, "minitest").match?(ci_log)
      end

      def name
        "Minitest"
      end

      def start!
        super

        minitest_plugin_path = File.expand_path("../..", __dir__)

        code = <<~EOM
          Rake::TestTask.new(:__ci_runner_test) do |t|
            t.libs << "test"
            t.libs << "lib"
            t.libs << "#{minitest_plugin_path}"
            t.test_files = #{failures.map(&:path)}
            t.ruby_opts << "-rrake"
          end

          Rake::Task[:__ci_runner_test].invoke
        EOM

        rakefile_path = File.expand_path("Rakefile", Dir.mktmpdir)
        File.write(rakefile_path, code)

        server = DRb.start_service("drbunix:", failures)

        env = { "TESTOPTS" => "--ci-runner=#{server.uri}" }
        env["SEED"] = seed if seed
        env["RUBY"] = ruby_path.to_s if ruby_path && ruby_path.exist?
        env["BUNDLE_GEMFILE"] = gemfile_path.to_s if gemfile_path && gemfile_path.exist?

        system(env, "bundle exec ruby -r'rake/testtask' #{rakefile_path}")

        DRb.stop_service
      end

      private

      def process_buffer
        super do
          match_data = minitest_failure
          next unless match_data

          file_path = valid_path?(match_data[:file_path]) ? match_data[:file_path] : find_test_location(match_data)

          @failures << TestFailure.new(match_data[:class], match_data[:test_name], file_path)
        end
      end

      def valid_path?(path)
        return false if path.nil?

        points_to_a_gem = %r{ruby/.*?/gems}

        !path.match?(points_to_a_gem)
      end

      def find_test_location(match_data)
        match = try_rails
        return match if match

        match = try_infer_file_from_class(match_data)
        return match if match

        match = try_stacktrace(match_data)
        return match if match

        raise("Can't find test location")
      end

      def underscore(camel_cased_word)
        return camel_cased_word.to_s unless /[A-Z-]|::/.match?(camel_cased_word)
        word = camel_cased_word.to_s.gsub("::", "/")

        word.gsub!(/([A-Z]+)(?=[A-Z][a-z])|([a-z\d])(?=[A-Z])/) { ($1 || $2) << "_" }
        word.tr!("-", "_")
        word.downcase!
        word
      end

      def try_stacktrace(match_data)
        regex = /\s*(\/.*?):\d+:in.*#{match_data[:class]}/

        @buffer.match(regex) { |match| match[1] }
      end

      def try_infer_file_from_class(match_data)
        file_name = underscore(match_data[:class].split("::").last)
        regex = /(\/.*#{file_name}.*?):\d+/

        @buffer.match(regex) { |match| match[1] }
      end

      def try_rails
        regex = /rails\s+test\s+(.*?):\d+/

        @buffer.match(regex) { |match| match[1] }
      end

      def minitest_failure
        regex = /(?:\s*)(?<class>[a-zA-Z0-9_:]+)\#(?<test_name>test_.+?)(:\s*$|\s+\[(?<file_path>.*):\d+\])/

        regex.match(@buffer)
      end
    end
  end
end
