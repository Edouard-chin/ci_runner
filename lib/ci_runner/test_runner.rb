# frozen_string_literal: true

require "bundler"
require "minitest/plugin"

module CIRunner
  class TestRunner
    class << self
      attr_accessor :failures
    end

    def initialize(failures)
      self.class.failures = failures
      @load_errors = []

      setup_load_path
      setup_bundler
      clear_argv
    end

    def setup_load_path
      $LOAD_PATH.unshift(File.expand_path("test", Dir.pwd))
    end

    def setup_bundler
      ENV["BUNDLE_GEMFILE"] = File.expand_path("Gemfile", Dir.pwd)
      Bundler.setup(:default, :test)
    end

    def clear_argv
      ARGV.clear
    end

    def run_failing_tests
      self.class.failures.each do |failure|
        require_file(failure.path)
      end

      Minitest.extensions << 'ci_runner'
    end

    private

    def require_file(path)
      # puts $LOAD_PATH
      require_relative path.to_s
    # rescue LoadError => e
    #   @load_errors << e
    end
  end
end
