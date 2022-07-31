# frozen_string_literal: true

require_relative "base"
require "drb/drb"
require "tempfile"

module CIRunner
  module Runners
    class MinitestRunner < Base
      def self.match?(ci_log)
        default_reporter = /(Finished in) \d+\.\d{6}s, \d+\.\d{4} runs\/s, \d+\.\d{4} assertions\/s\./

        Regexp.union(default_reporter, seed_flag, "minitest").match?(ci_log)
      end

      def self.seed_flag
        Regexp.union(
          /Run options:.*?--seed\s+(\d+)/, # Default Minitest Statistics Repoter
          /Running tests with run options.*--seed\s+(\d+)/, # MinitestReporters BaseReporter
          /Started with run options.*--seed\s+(\d+)/, # MinitestReporters ProgressReporter
        )
      end

      def initialize(*)
        @buffer = +""

        super
      end

      def name
        "Minitest"
      end

      def parse!
        @ci_log.each_line do |line|
          case line
          when self.class.seed_flag
            @seed = Regexp.last_match.captures.compact.first
          when /[^_-][rR]uby(?:[[:blank:]]*|\/)(\d\.\d\.\d+)p?(?!\/gems)/
            @ruby_version = Regexp.last_match(1)

            @buffer << line if buffering?
          when /BUNDLE_GEMFILE:[[:blank:]]*(.*)/
            @gemfile = Regexp.last_match(1).rstrip
          when /(Failure|Error):\s*\Z/
            process_buffer if buffering?
            @buffer.clear
            @buffer << line
          else
            @buffer << line if buffering?
          end
        end

        process_buffer if buffering?
      end

      def start!
        test_files = failures.map(&:path)

        code = <<~EOM
        Rake::TestTask.new(:__ci_runner_test) do |t|
          t.libs << "test"
          t.libs << "lib"
          t.test_files = #{test_files}
          t.ruby_opts << "-rrake"
        end

        Rake::Task[:__ci_runner_test].invoke
        EOM

        dir = Dir.mktmpdir
        rakefile_path = File.expand_path("Rakefile", dir)

        File.write(rakefile_path, code)

        if ruby_version && ruby_version != RUBY_VERSION
          ruby_path = Pathname(Dir.home).join(".rubies/ruby-#{ruby_version}/bin/ruby")

          unless ruby_path.exist?
            ::CLI::UI.puts(<<~EOM)
            {{warning:Couldn't find Ruby version #{ruby_version} on your system.}}
            {{warning:Searched in #{ruby_path}}}

            {{warning:The test run will start but will be running using your current Ruby version {{underline:#{RUBY_VERSION}}}.}}
          EOM

            ruby_path = nil
          end
        end

        if gemfile && !File.exist?(gemfile)
          ::CLI::UI.puts(<<~EOM)
          {{warning:Your CI run ran with the Gemfile #{gemfile}}}
          {{warning:I couldn't find this gemfile in your folder.}}

          {{warning:The test run will start but will be using the default Gemfile of your project}}
        EOM

          self.gemfile = nil
        end

        server = DRb.start_service("drbunix:", self)
        env = { "TESTOPTS" => "--ci-runner=#{server.uri}" }
        env["SEED"] = seed if seed
        env["RUBY"] = ruby_path.to_s if ruby_path
        env["BUNDLE_GEMFILE"] = gemfile if gemfile

        system(env, "bundle exec ruby -r'rake/testtask' #{rakefile_path}")

        DRb.stop_service
      end

      private

      def buffering?
        !@buffer.empty?
      end

      def process_buffer
        match_data = minitest_failure
        return unless match_data

        file_path = valid_path?(match_data[:file_path]) ? match_data[:file_path] : find_test_location(match_data)

        @failures << TestFailure.new(match_data[:class], match_data[:test_name], file_path)
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
        file_name = underscore(match_data[:class])
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
