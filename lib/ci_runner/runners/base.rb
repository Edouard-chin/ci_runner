# frozen_string_literal: true

require "pathname"

module CIRunner
  module Runners
    class Base
      attr_accessor :failures, :seed, :ruby_version, :gemfile

      def self.match?(_)
        raise NotImplementedError, "Subclass responsability"
      end

      def initialize(ci_log)
        @ci_log = ci_log
        @failures = []
        @buffer = +""
      end

      def parse!
        @ci_log.each_line do |line|
          case line
          when seed_regex
            @seed = first_matching_group(Regexp.last_match)
          when ruby_detection_regex
            @ruby_version = first_matching_group(Regexp.last_match)

            @buffer << line if buffering?
          when gemfile_detection_regex
            @gemfile = first_matching_group(Regexp.last_match)
          when buffer_detection_regex
            if ProjectConfiguration.instance.process_on_new_match? && buffering?
              process_buffer
              @buffer.clear
            end

            @buffer << line
          else
            @buffer << line if buffering?
          end
        end

        process_buffer if buffering?
      end

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

      def report
        using_ruby = ruby_version ? ruby_version : "No specific Ruby version detected. Will be using your current version #{RUBY_VERSION}"
        using_gemfile = gemfile ? gemfile : "No specific Gemfile detected. Will be using the default Gemfile of your project."

        ::CLI::UI.puts(<<~EOM)

          - Test framework detected:    {{info:#{name}}}
          - Detected Ruby version:      {{info:#{using_ruby}}}
          - Detected Gemfile:           {{info:#{using_gemfile}}}
          - Number of failings tests:   {{info:#{failures.count}}}
        EOM
      end

      private

      def process_buffer
        custom_project_regex = ProjectConfiguration.instance.test_failure_detection_regex

        if custom_project_regex
          custom_project_regex.match(@buffer) do |match_data|
            @failures << TestFailure.new(match_data[:class], match_data[:test_name], match_data[:file_path])
          end
        else
          yield
        end
      end

      def ruby_detection_regex
        return @ruby_detection_regex if defined?(@ruby_detection_regex)

        regexes = [
          ProjectConfiguration.instance.ruby_detection_regex,
          /[^_-][rR]uby(?:[[:blank:]]*|\/)(\d\.\d\.\d+)p?(?!\/gems)/,
        ].compact

        @ruby_detection_regex = Regexp.union(*regexes)
      end

      def gemfile_detection_regex
        return @gemfile_detection_regex if defined?(@gemfile_detection_regex)

        regexes = [
          ProjectConfiguration.instance.gemfile_detection_regex,
          /BUNDLE_GEMFILE:[[:blank:]]*(.*)/,
        ].compact

        @gemfile_detection_regex = Regexp.union(*regexes)
      end

      def seed_regex
        return @seed_regex if defined?(@seed_regex)

        regexes = [
          ProjectConfiguration.instance.seed_detection_regex,
          self.class::SEED_REGEX,
        ].compact

        @seed_regex = Regexp.union(*regexes)
      end

      def buffer_detection_regex
        return @buffer_detection_regex if defined?(@buffer_detection_regex)

        regexes = [
          ProjectConfiguration.instance.buffer_starts_regex,
          self.class::BUFFER_STARTS,
        ].compact

        @buffer_detection_regex = Regexp.union(*regexes)
      end

      def gemfile_path
        return unless gemfile

        Pathname(Dir.pwd).join(gemfile)
      end

      def ruby_path
        return unless ruby_version

        Pathname(Dir.home).join(".rubies/ruby-#{ruby_version}/bin/ruby")
      end

      def buffering?
        !@buffer.empty?
      end

      def first_matching_group(match_data)
        match_data.captures.find { |v| v }
      end
    end
  end
end
