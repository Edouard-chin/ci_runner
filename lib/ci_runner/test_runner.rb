# frozen_string_literal: true

require "bundler"
require "minitest/plugin"

module CIRunner
  class TestRunner
    class << self
      attr_accessor :failures
    end

    def initialize(failures, seed)
      self.class.failures = failures
      @load_errors = []

      setup_load_path
      setup_bundler
      setup_argv(seed)
    end

    def setup_load_path
      $LOAD_PATH.unshift(File.expand_path("test", Dir.pwd))
    end

    def setup_bundler
      ENV["BUNDLE_GEMFILE"] = File.expand_path("Gemfile", Dir.pwd)

      Bundler.setup(:default, :test)
    end

    def setup_argv(seed)
      ARGV.clear

      ARGV << "--seed" << seed.to_s if seed
    end

    def run_failing_tests
      self.class.failures.each do |failure|
        require_file(failure.path)
      end

      Minitest.extensions << 'ci_runner'
    end

    private

    def require_file(path)
      require_relative path.to_s
    rescue LoadError => e
      @load_errors << e
    end
  end
end
