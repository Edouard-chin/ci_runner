# frozen_string_literal: true

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
      end

      def parse!
        raise NotImplementedError, "Subclass responsability"
      end

      def start!
        raise NotImplementedError, "Subclass responsability"
      end

      def report
        using_ruby = ruby_version ? ruby_version : "No specific Ruby version detected. Will be using your current version {{#{RUBY_VERSION}}}"
        using_gemfile = gemfile ? gemfile : "No specific Gemfile detected. Will be using the default Gemfile of your project."

        ::CLI::UI.puts(<<~EOM)

          - Test framework detected:    {{info:#{name}}}
          - Detected Ruby version:      {{info:#{using_ruby}}}
          - Detected Gemfile:           {{info:#{using_gemfile}}}
          - Number of failings tests:   {{info:#{failures.count}}}
        EOM
      end
    end
  end
end
