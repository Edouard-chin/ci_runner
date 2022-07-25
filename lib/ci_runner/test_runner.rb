# frozen_string_literal: true

require "drb/drb"
require "tempfile"

module CIRunner
  class TestRunner
    attr_reader :failures

    def initialize(failures, seed, shell)
      @failures = failures
      @load_errors = []
      @shell = shell
      @seed = seed
    end

    def run_failing_tests
      @shell.say("Found #{failures.count} failing tests from the CI log. Running them now...", :green)

      DRb.start_service("druby://localhost:8787", self)
      test_files = failures.map(&:path)

      code = <<~EOM
        require "rake/testtask"

        Rake::TestTask.new(:__ci_runner_test) do |t|
          t.libs << "test"
          t.libs << "lib"
          t.test_files = #{test_files}
        end

        Rake::Task[:__ci_runner_test].invoke
      EOM

      dir = Dir.mktmpdir
      rakefile_path = File.expand_path("Rakefile", dir)

      File.write(rakefile_path, code)

      env = {
        "SEED" => @seed.to_s,
        "TESTOPTS" => "--ci-runner",
        "RUBY" => "/Users/edouard/.rubies/ruby-3.1.2/bin/ruby",
      }

      system(
        env,
        "bundle exec ruby #{rakefile_path}"
      )

      DRb.stop_service
    end
  end
end
