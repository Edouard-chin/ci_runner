# frozen_string_literal: true

require "test_helper"
require "pathname"
require "fileutils"

module CIRunner
  module Runners
    class MinitestRunnerTest < Minitest::Test
      def teardown
        Configuration::Project.instance.load!

        super
      end

      def test_parse_raw_minitest_log_failures
        log = read_fixture("raw_minitest_failures.log")
        parser = MinitestRunner.new(log)

        parser.parse!

        assert_equal(3, parser.failures.count)
        assert_equal("65000", parser.seed)
        assert_equal("2.7.2", parser.ruby_version)
        assert_nil(parser.gemfile)

        path = Pathname(Dir.pwd).join("test/github_diff_parser_test.rb")
        expected = [
          TestFailure.new("GithubDiffParserTest", "test_boom1", path),
          TestFailure.new("GithubDiffParserTest", "test_boom3", path),
          TestFailure.new("GithubDiffParserTest", "test_boom2", path),
        ]

        expected.each_with_index do |expected_failure, index|
          failure = parser.failures[index]

          assert_equal(expected_failure.klass, failure.klass)
          assert_equal(expected_failure.test_name, failure.test_name)
          assert_equal(expected_failure.path.to_s, failure.path)
        end
      end

      def test_parse_raw_minitest_log_errors
        log = read_fixture("raw_minitest_error.log")
        parser = MinitestRunner.new(log)

        parser.parse!

        assert_equal(1, parser.failures.count)
        assert_equal("20218", parser.seed)
        assert_equal("3.2.0", parser.ruby_version)
        assert_nil(parser.gemfile)

        expected = TestFailure.new(
          "TestReloading",
          "test_reload_recovers_from_name_errors__w__on_unload_callbacks_",
          Pathname(Dir.pwd).join("test/lib/zeitwerk/test_reloading.rb"),
        )
        failure = parser.failures[0]

        assert_equal(expected.klass, failure.klass)
        assert_equal(expected.test_name, failure.test_name)
        assert_equal(expected.path.to_s, failure.path)
      end

      def test_parse_rails_log
        log = read_fixture("rails.log")
        parser = MinitestRunner.new(log)

        parser.parse!

        assert_equal(9, parser.failures.count)
        assert_equal("32593", parser.seed)
        assert_equal("2.7.6", parser.ruby_version)
        assert_equal("gemfiles/rails_6_0.gemfile", parser.gemfile)

        path = Pathname(Dir.pwd).join("test/system/maintenance_tasks/runs_test.rb")
        expected = [
          TestFailure.new("MaintenanceTasks::RunsTest", "test_run_a_CSV_Task", path),
          TestFailure.new("MaintenanceTasks::RunsTest", "test_pause_a_Run", path),
          TestFailure.new("MaintenanceTasks::RunsTest", "test_cancel_a_stuck_Run", path),
          TestFailure.new("MaintenanceTasks::RunsTest", "test_cancel_a_Run", path),
          TestFailure.new("MaintenanceTasks::RunsTest", "test_errors_for_double_enqueue_are_shown", path),
          TestFailure.new("MaintenanceTasks::RunsTest", "test_resume_a_Run", path),
          TestFailure.new("MaintenanceTasks::RunsTest", "test_cancel_a_pausing_Run", path),
          TestFailure.new(
            "MaintenanceTasks::RunsTest",
            "test_errors_for_invalid_pause_or_cancel_due_to_stale_UI_are_shown",
            path,
          ),
          TestFailure.new("MaintenanceTasks::RunsTest", "test_run_a_Task", path),
        ]

        expected.each_with_index do |expected_failure, index|
          failure = parser.failures[index]

          assert_equal(expected_failure.klass, failure.klass)
          assert_equal(expected_failure.test_name, failure.test_name)
          assert_equal(expected_failure.path.to_s, failure.path)
        end
      end

      # In this test, the test suite name "I18nBackendPluralizationFallbackTest", doesn't
      # map to a file called `i18n_backend_pluralization...`.
      def test_parse_log_with_inconsistent_class_and_file_name
        log = read_fixture("i18n.log")
        parser = MinitestRunner.new(log)

        parser.parse!

        assert_equal(1, parser.failures.count)
        assert_equal("54606", parser.seed)
        assert_equal("3.0.4", parser.ruby_version)
        assert_equal("Gemfile", parser.gemfile)

        expected = TestFailure.new(
          "I18nBackendPluralizationFallbackTest",
          "test_fallbacks:_nils_are_ignored_and_fallback_is_applied,_with_custom_rule",
          Pathname(Dir.pwd).join("test/backend/pluralization_fallback_test.rb"),
        )
        failure = parser.failures[0]

        assert_equal(expected.klass, failure.klass)
        assert_equal(expected.test_name, failure.test_name)
        assert_equal(expected.path.to_s, failure.path)
      end

      def test_when_projet_uses_custom_regexes
        log = read_fixture("custom_regexes.log")
        runner = MinitestRunner.new(log)

        Dir.chdir(Dir.home) do
          config_file = Configuration::Project.instance.config_file
          Dir.mkdir(config_file.dirname)

          config_file.write(<<~EOM)
            ---
            ruby_regex: 'My Ruby version: (\\d\\.\\d\\.\\d)'
            gemfile_regex: 'Gemfile used: (.*)'
            seed_regex: 'Running with the seed value (\\d+)'
          EOM

          Configuration::Project.instance.load!
        end

        runner.parse!

        assert_equal("Gemfile_AR_5_1", runner.gemfile)
        assert_equal("3.2.0", runner.ruby_version)
        assert_equal("65123", runner.seed)
      end

      def test_when_projet_uses_different_buffer_starts_regex
        log = read_fixture("custom_buffer_starts.log")
        runner = MinitestRunner.new(log)

        Dir.chdir(Dir.home) do
          config_file = Configuration::Project.instance.config_file
          Dir.mkdir(config_file.dirname)

          config_file.write(<<~EOM)
            ---
            buffer_starts_regex: 'End of test. Results finished in \\d+ seconds.'
          EOM

          Configuration::Project.instance.load!
        end

        runner.parse!

        expected = [
          TestFailure.new(
            "MaintenanceTasks::RunsTest",
            "test_run_a_CSV_Task",
            "test/system/maintenance_tasks/runs_test.rb",
          ),
          TestFailure.new(
            "MaintenanceTasks::RunsTest",
            "test_pause_a_Run",
            "test/system/maintenance_tasks/runs_test.rb",
          ),
        ]

        assert_equal(2, runner.failures.count)

        expected.each_with_index do |failure, index|
          assert_equal(failure.test_name, runner.failures[index].test_name)
          assert_equal(failure.klass, runner.failures[index].klass)
          assert_equal(failure.path, runner.failures[index].path)
        end
      end

      def test_when_projet_uses_custom_failure_regex
        log = read_fixture("custom_failures.log")
        runner = MinitestRunner.new(log)

        Dir.chdir(Dir.home) do
          config_file = Configuration::Project.instance.config_file
          Dir.mkdir(config_file.dirname)

          config_file.write(<<~EOM)
            ---
            failures_regex: !ruby/regexp '/(?:\s*)(?<class>[a-zA-Z0-9_:]+)\#(?<test_name>test_.+?)(?::\s*$).*bin\/rerun_test[[:blank:]](?<file_path>.*)[[:blank:]]-n/m'
          EOM

          Configuration::Project.instance.load!
        end

        runner.parse!

        expected = TestFailure.new(
          "TestReloading",
          "test_reload_recovers_from_name_errors__w__on_unload_callbacks_",
          "path/to/file.rb",
        )

        assert_equal(1, runner.failures.count)
        assert_equal(expected.test_name, runner.failures[0].test_name)
        assert_equal(expected.klass, runner.failures[0].klass)
        assert_equal(expected.path, runner.failures[0].path)
      end

      def test_when_projet_uses_custom_invalid_failure_regex
        log = read_fixture("custom_failures.log")
        runner = MinitestRunner.new(log)

        Dir.chdir(Dir.home) do
          config_file = Configuration::Project.instance.config_file
          Dir.mkdir(config_file.dirname)

          config_file.write(<<~EOM)
            ---
            failures_regex: '(bla|blo)_test.rb'
          EOM

          Configuration::Project.instance.load!
        end

        error = assert_raises(Error) do
          runner.parse!
        end

        assert_equal(<<~EOM, error.message)
          The {{warning:failures_regex}} configuration of your project doesn't include expected named captures.
          CI Runner expects the following Regexp named captures: ["file_path", "test_name", "class"].

          Your Regex should look something like {{info:/(?<file_path>...)(?<test_name>...)(?<class>...)/}}
        EOM
      end

      def test_parse_namespaced_class_location_infer_from_stacktrace
        log = read_fixture("minitest_namespace.log")
        parser = MinitestRunner.new(log)

        parser.parse!

        assert_equal(1, parser.failures.count)

        expected = TestFailure.new(
          "CIRunner::GitHelperTest",
          "test_repository_from_remote_git_origin",
          "test/git_helper_test.rb",
        )
        failure = parser.failures[0]

        assert_equal(expected.klass, failure.klass)
        assert_equal(expected.test_name, failure.test_name)
        assert_equal(expected.path.to_s, failure.path)
      end

      def test_run_one_runnable
        runner = MinitestRunner.new(nil)
        runner.failures = [TestFailure.new("FooTest", "test_one", "test/fixtures/tests/foo_test.rb")]
        runner.seed = "60212"

        stdout, _ = capture_io do
          runner.start!
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
        runner = MinitestRunner.new(nil)
        runner.failures = [
          TestFailure.new("FooTest", "test_one", "test/fixtures/tests/foo_test.rb"),
          TestFailure.new("FooTest", "test_two", "test/fixtures/tests/foo_test.rb"),
        ]
        runner.seed = "10331"

        stdout, _ = capture_io do
          runner.start!
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
        runner = MinitestRunner.new(nil)
        runner.failures = [
          TestFailure.new("FooTest", "test_one", "test/fixtures/tests/foo_test.rb"),
          TestFailure.new("SomeFolder::BarTest", "test_two", "test/fixtures/tests/some_folder/bar_test.rb"),
        ]
        runner.seed = "10331"

        stdout, _ = capture_io do
          runner.start!
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
        runner = MinitestRunner.new(nil)
        runner.failures = [
          TestFailure.new("FooTest", "test_unexisting", "test/fixtures/tests/foo_test.rb"),
        ]
        runner.seed = "1044"

        stdout, _ = capture_io do
          runner.start!
        end

        assert_equal(<<~EOM, clean_statistics(stdout))
          Run options: --seed 1044

          # Running:



          Finished in 0s.

          0 runs, 0 assertions, 0 failures, 0 errors, 0 skips
        EOM
      end

      def test_uses_the_right_ruby_version_when_it_exists
        runner = MinitestRunner.new(nil)
        runner.failures = [
          TestFailure.new("FooTest", "test_unexisting", "test/fixtures/tests/foo_test.rb"),
        ]
        runner.seed = "1044"
        runner.ruby_version = "2.7.6"

        stub_ruby = <<~CODE
          #!/bin/sh

          echo Stub Ruby executable called!
        CODE
        executable_path = Pathname(Dir.home).join(".rubies/ruby-2.7.6/bin/ruby")
        FileUtils.mkdir_p(executable_path.dirname)

        File.write(executable_path, stub_ruby)
        FileUtils.chmod("+x", executable_path)

        stdout, _ = capture_io do
          runner.start!
        end

        assert_equal("Stub Ruby executable called!\n", stdout)
      end

      def test_uses_current_ruby_when_ruby_version_doesnt_exist
        runner = MinitestRunner.new(nil)
        runner.failures = [TestFailure.new("FooTest", "test_one", "test/fixtures/tests/foo_test.rb")]
        runner.seed = "1044"
        runner.ruby_version = "2.7.6"

        stdout, _ = capture_io do
          runner.start!
        end

        assert_equal(<<~EOM, clean_statistics(stdout))
          \e[0;33mCouldn't find Ruby version 2.7.6 on your system.\e[0m
          \e[0;33m\e[0m\e[0;33mSearched in #{Dir.home}/.rubies/ruby-2.7.6/bin/ruby\e[0m
          \e[0;33m\e[0m\e[0;33m\e[0m
          \e[0;33m\e[0m\e[0;33m\e[0m\e[0;33mThe test run will start but will be running using your current Ruby version \e[0;33;4m#{RUBY_VERSION}\e[0;33m.\e[0m
          \e[0;33m\e[0m\e[0;33m\e[0m\e[0;33m\e[0;33;4m\e[0;33m\e[0m
          Run options: --seed 1044

          # Running:

          .

          Finished in 0s.

          1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
        EOM
      end

      def test_uses_right_gemfile_when_it_exists
        runner = MinitestRunner.new(nil)
        runner.failures = [
          TestFailure.new("WarningTest", "test_right_gemfile_picked", "test/fixtures/tests/warning_test.rb"),
        ]
        runner.seed = "1044"
        runner.gemfile = File.expand_path("../fixtures/Gemfile_dummy", __dir__)

        capture_subprocess_io do
          Bundler.unbundled_system({ "BUNDLE_GEMFILE" => runner.gemfile }, "bundle install")
        end

        stdout, _ = capture_io do
          Bundler.with_unbundled_env do
            runner.start!
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
        runner = MinitestRunner.new(StringIO.new("a"))
        runner.failures = [
          TestFailure.new("WarningTest", "test_default_gemfile_picked", "test/fixtures/tests/warning_test.rb"),
        ]
        runner.seed = "1044"
        runner.gemfile = "Gemfile_unexisting"

        stdout, _ = capture_io do
          runner.start!
        end

        assert_equal(<<~EOM, clean_statistics(stdout))
          \e[0;33mYour CI run ran with the Gemfile Gemfile_unexisting\e[0m
          \e[0;33m\e[0m\e[0;33mI couldn't find this gemfile in your folder.\e[0m
          \e[0;33m\e[0m\e[0;33m\e[0m\n\e[0;33m\e[0m\e[0;33m\e[0m\e[0;33mThe test run will start but will be using the default Gemfile of your project\e[0m
          \e[0;33m\e[0m\e[0;33m\e[0m\e[0;33m\e[0m
          Run options: --seed 1044

          # Running:

          .

          Finished in 0s.

          1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
        EOM
      end

      private

      def clean_statistics(string)
        regex = %r{(Finished in) \d+\.\d{6}s, \d+\.\d{4} runs/s, \d+\.\d{4} assertions/s\.}

        string.gsub(regex, '\1 0s.')
      end
    end
  end
end
