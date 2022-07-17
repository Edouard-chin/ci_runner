# frozen_string_literal: true

require "test_helper"

module CIRunner
  class TestRunFinderTest < Minitest::Test
    def test_fetch_ci_checks_returns_checks
      stub_request(:get, "https://api.github.com/repos/canatacorp/catana/commits/abcdef/check-runs")
        .to_return_json(status: 200, body: { total_count: 1, check_runs: [id: 1, name: "foo"] })

      stdout, _ = capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          checks = TestRunFinder.fetch_ci_checks("canatacorp/catana", "abcdef")

          assert_equal({ "total_count" => 1, "check_runs" => [{ "id" => 1, "name" => "foo" }] }, checks)
        end
      end

      assert_match(/Fetching failed CI checks from GitHub for commit/, stdout)
      assert_requested(:get, "https://api.github.com/repos/canatacorp/catana/commits/abcdef/check-runs")
    end

    def test_fetch_ci_checks_when_checks_cant_be_retrieved
      stub_request(:get, "https://api.github.com/repos/canatacorp/catana/commits/abcdef/check-runs")
        .to_return(status: 404, body: "Not found")

      stdout, _ = capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          TestRunFinder.fetch_ci_checks("canatacorp/catana", "abcdef") do
            puts "Couldn't retrieve CI checks"
          end
        end
      end

      assert_match("Couldn't retrieve CI checks", stdout)
      assert_requested(:get, "https://api.github.com/repos/canatacorp/catana/commits/abcdef/check-runs")
    end

    def test_find_when_the_run_failed
      ci_checks = {
        "check_runs" => [
          { "name" => "Test Ruby 2.7", "conclusion" => "failure" },
          { "name" => "Test Ruby 3.0", "conclusion" => "failure" },
        ],
      }

      check_run = TestRunFinder.find(ci_checks, "Test Ruby 3.0")

      assert_equal({ "name" => "Test Ruby 3.0", "conclusion" => "failure" }, check_run)
    end

    def test_find_when_the_run_succeed
      ci_checks = {
        "check_runs" => [
          { "name" => "Test Ruby 2.7", "conclusion" => "failure" },
          { "name" => "Test Ruby 3.0", "conclusion" => "success" },
        ],
      }

      error = assert_raises(Error) do
        TestRunFinder.find(ci_checks, "Test Ruby 3.0")
      end

      assert_equal(
        "The CI check 'Test Ruby 3.0' was successfull. There should be no failing tests to rerun.",
        error.message,
      )
    end

    def test_find_when_the_run_doesnt_exist
      ci_checks = {
        "check_runs" => [
          { "name" => "Test Ruby 2.7", "conclusion" => "failure" },
          { "name" => "Test Ruby 3.0", "conclusion" => "success" },
        ],
      }

      error = assert_raises(Error) do
        TestRunFinder.find(ci_checks, "Test Ruby 1.8")
      end

      assert_equal(<<~EOM, error.message)
        Couldn't find a CI check called 'Test Ruby 1.8'.
        CI checks on this commit are:

        \e[31m✗\e[0m Test Ruby 2.7
        \e[32m✓\e[0m Test Ruby 3.0
      EOM
    end

    def test_find_when_there_are_no_checks
      ci_checks = { "check_runs" => [] }

      error = assert_raises(Error) do
        TestRunFinder.find(ci_checks, "Test Ruby 1.8")
      end

      assert_equal(<<~EOM, error.message)
        Couldn't find a CI check called 'Test Ruby 1.8'.

        There are no CI checks on this commit.
      EOM
    end

    def test_detect_runner_minitest_1
      log = read_fixture("raw_minitest_error.log")

      runner = TestRunFinder.detect_runner(log.read)

      assert_instance_of(Runners::MinitestRunner, runner)
    end

    def test_detect_runner_minitest_2
      log = read_fixture("raw_minitest_failures.log")

      runner = TestRunFinder.detect_runner(log.read)

      assert_instance_of(Runners::MinitestRunner, runner)
    end

    def test_detect_runner_minitest_3
      log = read_fixture("rails.log")

      runner = TestRunFinder.detect_runner(log.read)

      assert_instance_of(Runners::MinitestRunner, runner)
    end

    def test_detect_runner_minitest_4
      log = read_fixture("i18n.log")

      runner = TestRunFinder.detect_runner(log.read)

      assert_instance_of(Runners::MinitestRunner, runner)
    end

    def test_detect_runner_rspec
      log = read_fixture("rspec.log")

      runner = TestRunFinder.detect_runner(log.read)

      assert_instance_of(Runners::RSpec, runner)
    end

    def test_detect_runner_fails_to_detect
      error = assert_raises(Error) do
        TestRunFinder.detect_runner("some_log")
      end

      assert_equal("Couldn't detect the test runner", error.message)
    end
  end
end
