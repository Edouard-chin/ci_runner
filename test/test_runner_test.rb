# frozen_string_literal: true

require "test_helper"
require "stringio"
require "fileutils"

module CIRunner
  class TestRunnerTest < Minitest::Test
    def test_run_one_runnable
      log_parser = LogParser.new(StringIO.new("a"))
      log_parser.failures = [TestFailure.new("FooTest", "test_one", "test/fixtures/tests/foo_test.rb")]
      log_parser.seed = 60212

      stdout, _ = capture_subprocess_io do
        TestRunner.new(log_parser).run_failing_tests
      end

      assert_equal(<<~EOM, clean_statistics(stdout))
        Run options: --seed 60212

        # Running:

        .

        Finished in 0s.

        1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
      EOM
    end

    def test_run_two_runnables
      log_parser = LogParser.new(StringIO.new("a"))
      log_parser.failures = [
        TestFailure.new("FooTest", "test_one", "test/fixtures/tests/foo_test.rb"),
        TestFailure.new("FooTest", "test_two", "test/fixtures/tests/foo_test.rb"),
      ]
      log_parser.seed = 10331

      stdout, _ = capture_subprocess_io do
        TestRunner.new(log_parser).run_failing_tests
      end

      assert_equal(<<~EOM, clean_statistics(stdout))
        Run options: --seed 10331

        # Running:

        ..

        Finished in 0s.

        2 runs, 2 assertions, 0 failures, 0 errors, 0 skips
      EOM
    end

    def test_run_two_suites
      log_parser = LogParser.new(StringIO.new("a"))
      log_parser.failures = [
        TestFailure.new("FooTest", "test_one", "test/fixtures/tests/foo_test.rb"),
        TestFailure.new("SomeFolder::BarTest", "test_two", "test/fixtures/tests/some_folder/bar_test.rb"),
      ]
      log_parser.seed = 10331

      stdout, _ = capture_subprocess_io do
        TestRunner.new(log_parser).run_failing_tests
      end

      assert_equal(<<~EOM, clean_statistics(stdout))
        Run options: --seed 10331

        # Running:

        ..

        Finished in 0s.

        2 runs, 5 assertions, 0 failures, 0 errors, 0 skips
      EOM
    end

    def test_run_no_longer_existing_runnable
      log_parser = LogParser.new(StringIO.new("a"))
      log_parser.failures = [
        TestFailure.new("FooTest", "test_unexisting", "test/fixtures/tests/foo_test.rb"),
      ]
      log_parser.seed = 1044

      stdout, _ = capture_subprocess_io do
        TestRunner.new(log_parser).run_failing_tests
      end

      assert_equal(<<~EOM, clean_statistics(stdout))
        Run options: --seed 1044

        # Running:



        Finished in 0s.

        0 runs, 0 assertions, 0 failures, 0 errors, 0 skips
      EOM
    end

    def test_uses_the_right_ruby_version_when_it_exists
      log_parser = LogParser.new(StringIO.new("a"))
      log_parser.failures = [
        TestFailure.new("FooTest", "test_unexisting", "test/fixtures/tests/foo_test.rb"),
      ]
      log_parser.seed = 1044
      log_parser.ruby_version = "2.7.6"

      stub_ruby = <<~CODE
        #!/bin/sh

        echo Stub Ruby executable called!
      CODE
      executable_path = Pathname(Dir.home).join(".rubies/ruby-2.7.6/bin/ruby")
      FileUtils.mkdir_p(executable_path.dirname)

      File.write(executable_path, stub_ruby)
      FileUtils.chmod("+x", executable_path)

      stdout, _ = capture_subprocess_io do
        TestRunner.new(log_parser).run_failing_tests
      end

      assert_equal("Stub Ruby executable called!\n", stdout)
    end

    def test_uses_current_ruby_when_ruby_version_doesnt_exist
      log_parser = LogParser.new(StringIO.new("a"))
      log_parser.failures = [TestFailure.new("FooTest", "test_one", "test/fixtures/tests/foo_test.rb")]
      log_parser.seed = 1044
      log_parser.ruby_version = "2.7.6"

      stdout = ""

      subprocess_stdout, _ = capture_subprocess_io do
        stdout, _ = capture_io do
          TestRunner.new(log_parser).run_failing_tests
        end
      end

      assert_equal(<<~EOM, stdout)
        \e[0;33mCouldn't find Ruby version 2.7.6 on your system.\e[0m
        \e[0;33m\e[0m\e[0;33mSearched in #{Dir.home}/.rubies/ruby-2.7.6/bin/ruby\e[0m
        \e[0;33m\e[0m\e[0;33m\e[0m
        \e[0;33m\e[0m\e[0;33m\e[0m\e[0;33mThe test run will start but will be running using your current Ruby version \e[0;33;4m#{RUBY_VERSION}\e[0;33m.\e[0m
        \e[0;33m\e[0m\e[0;33m\e[0m\e[0;33m\e[0;33;4m\e[0;33m\e[0m
      EOM

      assert_equal(<<~EOM, clean_statistics(subprocess_stdout))
        Run options: --seed 1044

        # Running:

        .

        Finished in 0s.

        1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
      EOM
    end

    def test_uses_right_gemfile_when_it_exists
      log_parser = LogParser.new(StringIO.new("a"))
      log_parser.failures = [TestFailure.new("WarningTest", "test_right_gemfile_picked", "test/fixtures/tests/warning_test.rb")]
      log_parser.seed = 1044
      log_parser.gemfile = File.expand_path("fixtures/Gemfile_dummy", __dir__)

      capture_subprocess_io do
        Bundler.unbundled_system({ "BUNDLE_GEMFILE" => log_parser.gemfile }, "bundle install")
      end

      stdout, _ = capture_subprocess_io do
        Bundler.with_unbundled_env do
          TestRunner.new(log_parser).run_failing_tests
        end
      end

      assert_equal(<<~EOM, clean_statistics(stdout))
        Run options: --seed 1044

        # Running:

        .

        Finished in 0s.

        1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
      EOM
    end

    def test_uses_default_gemfile_when_gemfile_cant_be_found_locally
      log_parser = LogParser.new(StringIO.new("a"))
      log_parser.failures = [TestFailure.new("WarningTest", "test_default_gemfile_picked", "test/fixtures/tests/warning_test.rb")]
      log_parser.seed = 1044
      log_parser.gemfile = File.expand_path("fixtures/Gemfile_unexisting", __dir__)

      stdout = ""

      subprocess_stdout, _ = capture_subprocess_io do
        stdout, _ = capture_io do
          TestRunner.new(log_parser).run_failing_tests
        end
      end

      assert_equal(<<~EOM, stdout)
        \e[0;33mYour CI run ran with the Gemfile /Users/edouard/code/projects/ci_runner/test/fixtures/Gemfile_unexisting\e[0m
        \e[0;33m\e[0m\e[0;33mI couldn't find this gemfile in your folder.\e[0m
        \e[0;33m\e[0m\e[0;33m\e[0m\n\e[0;33m\e[0m\e[0;33m\e[0m\e[0;33mThe test run will start but will be using the default Gemfile of your project\e[0m
        \e[0;33m\e[0m\e[0;33m\e[0m\e[0;33m\e[0m
      EOM

      assert_equal(<<~EOM, clean_statistics(subprocess_stdout))
        Run options: --seed 1044

        # Running:

        .

        Finished in 0s.

        1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
      EOM
    end

    private

    def clean_statistics(string)
      regex = /(Finished in) \d+\.\d{6}s, \d+\.\d{4} runs\/s, \d+\.\d{4} assertions\/s\./

      string.gsub(regex, '\1 0s.')
    end
  end
end
