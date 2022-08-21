# frozen_string_literal: true

require "pathname"
require "open3"

module CIRunner
  module Runners
    class Base
      # @return [Array<TestFailure>]
      attr_accessor :failures

      # @return (See TestFailure#seed)
      attr_accessor :seed

      # @return [String] The ruby version detected.
      attr_accessor :ruby_version

      # @return [String] The Gemfile detected.
      attr_accessor :gemfile

      # Children needs to implement this method to tell if they recognize the log output and if it can process them.
      #
      # @param _ [String] The CI log output.
      #
      # @return [Boolean]
      def self.match?(_)
        raise NotImplementedError, "Subclass responsability"
      end

      # @param ci_log [String] The CI log output.
      def initialize(ci_log)
        @ci_log = ci_log
        @failures = []
        @buffer = +""
      end

      # Parse the CI log. Iterate over each line and try to detect:
      #
      # - The Ruby version
      # - The Gemfile used
      # - Failures (Including their names, their class and the file path)
      #
      # @return [void]
      def parse!
        @ci_log.each_line do |line|
          line_no_ansi_color = line.gsub(/\e\[\d+m/, "")

          case line_no_ansi_color
          when seed_regex
            @seed = first_matching_group(Regexp.last_match)
          when ruby_detection_regex
            @ruby_version = first_matching_group(Regexp.last_match)

            @buffer << line_no_ansi_color if buffering?
          when gemfile_detection_regex
            @gemfile = first_matching_group(Regexp.last_match)
          when buffer_detection_regex
            if Configuration::Project.instance.process_on_new_match? && buffering?
              process_buffer
              @buffer.clear
            end

            @buffer << line_no_ansi_color
          else
            @buffer << line_no_ansi_color if buffering?
          end
        end

        process_buffer if buffering?
      end

      # Entrypoint to start the runner process once it finishes parsing the log.
      #
      # @return [Void]
      def start!
        if ruby_version && !ruby_path.exist?
          ::CLI::UI.puts(<<~EOM)
            {{warning:Couldn't find Ruby version #{ruby_version} on your system.}}
            {{warning:Searched in #{ruby_path}}}

            {{warning:The test run will start but will be running using your current Ruby version {{underline:#{RUBY_VERSION}}}.}}
          EOM
        end

        if gemfile && !gemfile_path.exist?
          ::CLI::UI.puts(<<~EOM)
            {{warning:Your CI run ran with the Gemfile #{gemfile}}}
            {{warning:I couldn't find this gemfile in your folder.}}

            {{warning:The test run will start but will be using the default Gemfile of your project}}
          EOM
        end
      end

      # Output useful information to the user before the test starts. This can only be called after the runner finished
      # parsing the log.
      #
      # @return [void]
      def report
        default_ruby = "No specific Ruby version detected. Will be using your current version #{RUBY_VERSION}"
        using_ruby = ruby_version ? ruby_version : default_ruby

        default_gemfile = "No specific Gemfile detected. Will be using the default Gemfile of your project."
        using_gemfile = gemfile ? gemfile : default_gemfile

        ::CLI::UI.puts(<<~EOM)

          - Test framework detected:    {{info:#{name}}}
          - Detected Ruby version:      {{info:#{using_ruby}}}
          - Detected Gemfile:           {{info:#{using_gemfile}}}
          - Number of failings tests:   {{info:#{failures.count}}}
        EOM
      end

      private

      # Process the +@buffer+ to find any test failures. Uses the project's regex if set, or fallbacks to
      # the default set of regexes this gem provides.
      #
      # See Project#buffer_starts_regex for explanation on the difference between the buffer and the CI log output.
      #
      # @return [void]
      def process_buffer
        custom_project_regex = Configuration::Project.instance.test_failure_detection_regex

        if custom_project_regex
          custom_project_regex.match(@buffer) do |match_data|
            @failures << TestFailure.new(match_data[:class], match_data[:test_name], match_data[:file_path])
          end
        else
          yield
        end
      end

      # See Configuration::Project#ruby_detection_regex
      #
      # @return [Regexp]
      def ruby_detection_regex
        return @ruby_detection_regex if defined?(@ruby_detection_regex)

        regexes = [
          Configuration::Project.instance.ruby_detection_regex,
          %r{[^_-][rR]uby(?:[[:blank:]]*|/)(\d\.\d\.\d+)p?(?!/gems)},
        ].compact

        @ruby_detection_regex = Regexp.union(*regexes)
      end

      # See Configuration::Project#gemfile_detection_regex
      #
      # @return [Regexp]
      def gemfile_detection_regex
        return @gemfile_detection_regex if defined?(@gemfile_detection_regex)

        regexes = [
          Configuration::Project.instance.gemfile_detection_regex,
          /BUNDLE_GEMFILE:[[:blank:]]*(.*)/,
        ].compact

        @gemfile_detection_regex = Regexp.union(*regexes)
      end

      # See Configuration::Project#seed_detection_regex
      #
      # @return [Regexp]
      def seed_regex
        return @seed_regex if defined?(@seed_regex)

        regexes = [
          Configuration::Project.instance.seed_detection_regex,
          self.class::SEED_REGEX,
        ].compact

        @seed_regex = Regexp.union(*regexes)
      end

      # See Configuration::Project#buffer_starts_regex
      #
      # @return [Regexp]
      def buffer_detection_regex
        return @buffer_detection_regex if defined?(@buffer_detection_regex)

        regexes = [
          Configuration::Project.instance.buffer_starts_regex,
          self.class::BUFFER_STARTS,
        ].compact

        @buffer_detection_regex = Regexp.union(*regexes)
      end

      # @return [Pathname, nil] The absolute path of the detected Gemfile based on where the user ran
      #   the `ci_runner` command from. Nil in no Gemfile was detected during parsing.
      def gemfile_path
        return unless gemfile

        Pathname(Dir.pwd).join(gemfile)
      end

      # @return [Pathname, nil] The absolute path of the Ruby binary on the user's machine.
      #   Nil if no Ruby version was detected when parsing.
      #
      # @return [Pathname]
      def ruby_path
        return unless ruby_version

        Pathname(Dir.home).join(".rubies/ruby-#{ruby_version}/bin/ruby")
      end

      # @return [Boolean]
      def buffering?
        !@buffer.empty?
      end

      # Regexp#union with capturing groups makes it difficult to know which subregex matched
      # and therefore which group to get. Convenient method to get the first whatever value is non nil.
      # There should be only one truty value in all groups.
      #
      # @param match_data [MatchData]
      #
      # @return [String]
      def first_matching_group(match_data)
        match_data.captures.find { |v| v }&.rstrip
      end

      # Runs a command and stream its output. We can't use `system` directly, as otherwise the
      # streamed ouput won't fit properly inside the ::CLI::UI frame.
      #
      # @param env [Hash] A hash of environment variables to pass to the subprocess
      # @param command [String] The command itself
      #
      # @return [void]
      def execute_within_frame(env, command)
        Open3.popen3(env, command) do |_, stdout, stderr, _|
          while (char = stdout.getc)
            print(char)
          end

          print(stderr.read)
        end
      end
    end
  end
end
