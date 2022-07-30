# frozen_string_literal: true

require "test_helper"
require "pathname"

module CIRunner
  class LogParserTest < Minitest::Test
    def test_parse_raw_minitest_log_failures
      log = read_fixture("raw_minitest_failures.log")
      parser = LogParser.new(log)

      parser.parse

      assert_equal(3, parser.failures.count)
      assert_equal(65000, parser.seed)

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
      parser = LogParser.new(log)

      parser.parse

      assert_equal(1, parser.failures.count)
      assert_equal(20218, parser.seed)

      expected = TestFailure.new(
        "TestReloading",
        "test_reload_recovers_from_name_errors__w__on_unload_callbacks_",
        Pathname(Dir.pwd).join("test/lib/zeitwerk/test_reloading.rb")
      )
      failure = parser.failures[0]

      assert_equal(expected.klass, failure.klass)
      assert_equal(expected.test_name, failure.test_name)
      assert_equal(expected.path.to_s, failure.path)
    end

    def test_parse_rails_log
      log = read_fixture("rails.log")
      parser = LogParser.new(log)

      parser.parse
      byebug

      assert_equal(9, parser.failures.count)
      assert_equal(32593, parser.seed)

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
          path
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
      parser = LogParser.new(log)

      parser.parse

      assert_equal(1, parser.failures.count)
      assert_equal(54606, parser.seed)

      expected = TestFailure.new(
        "I18nBackendPluralizationFallbackTest",
        "test_fallbacks:_nils_are_ignored_and_fallback_is_applied,_with_custom_rule",
        Pathname(Dir.pwd).join("test/backend/pluralization_fallback_test.rb")
      )
      failure = parser.failures[0]

      assert_equal(expected.klass, failure.klass)
      assert_equal(expected.test_name, failure.test_name)
      assert_equal(expected.path.to_s, failure.path)
    end
  end
end
