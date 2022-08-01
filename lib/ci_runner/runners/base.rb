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
        raise NotImplementedError, "Subclass responsability"
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
    end
  end
end
