# frozen_string_literal: true

require "drb/drb"
require "tempfile"
require "open3"

module CIRunner
  class TestRunner
    attr_reader :failures

    def initialize(log_parser)
      @log_parser = log_parser
      @failures = log_parser.failures
      @load_errors = []
    end

    def run_failing_tests
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

      if @log_parser.ruby_version && @log_parser.ruby_version != RUBY_VERSION
        ruby_path = Pathname(Dir.home).join(".rubies/ruby-#{@log_parser.ruby_version}/bin/ruby")

        unless ruby_path.exist?
          ::CLI::UI.puts(<<~EOM)
            {{warning:Couldn't find Ruby version #{@log_parser.ruby_version} on your system.}}
            {{warning:Searched in #{ruby_path}}}

            {{warning:The test run will start but will be running using Ruby version {{underline:#{RUBY_VERSION}}}.}}
          EOM

          ruby_path = nil
        end
      end

      gemfile_path = @log_parser.gemfile

      if @log_parser.gemfile && !File.exist?(@log_parser.gemfile)
        ::CLI::UI.puts(<<~EOM)
          {{warning:Your CI run ran with the Gemfile #{@log_parser.gemfile}}}
          {{warning:I couldn't find this gemfile in your folder.}}

          {{warning:The test run will start but will be using the default Gemfile of your project}}
        EOM

        gemfile_path = nil
      end

      env = { "TESTOPTS" => "--ci-runner" }
      env["SEED"] = @log_parser.seed.to_s if @log_parser.seed
      env["RUBY"] = ruby_path.to_s if ruby_path
      env["BUNDLE_GEMFILE"] = gemfile_path if gemfile_path

      if gemfile_path
        _, status = Open3.capture2(env, "bundle check")

        unless status.success?
          ::CLI::UI.frame("Bundler Dependencies") do
            ::CLI::UI.puts(<<~EOM)
              {{warning:The dependencies listed in the Gemfile #{gemfile_path} are not installed in your system.}}

              I'll be installing them now.
            EOM

            system(env, "bundle install")

            ::CLI::UI.puts("{{success:Resuming test run}}")
          end
        end
      end

      DRb.start_service("druby://localhost:8787", self)

      system(
        env,
        "bundle exec ruby #{rakefile_path}"
      )

      DRb.stop_service
    end
  end
end
