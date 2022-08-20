# frozen_string_literal: true

require "test_helper"

module CIRunner
  class TestRunFinderTest < Minitest::Test
    def test_fetch_ci_checks_returns_checks
      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
        .to_return_json(
          status: 200,
          body: {
            total_count: 1,
            check_runs: [
              { id: 1, name: "foo", conclusion: "success", app: { slug: "github-actions" } },
            ],
          },
        )

      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/statuses")
        .to_return_json(status: 200, body: "[]")

      stdout, _ = capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          checks = TestRunFinder.fetch_ci_checks("catanacorp/catana", "abcdef")

          assert_equal(1, checks.count)
          assert_equal("catanacorp/catana", checks.first.repository)
          assert_equal("abcdef", checks.first.commit)
          assert_equal("foo", checks.first.name)
          assert_equal("success", checks.first.status)
          assert_equal(1, checks.first.id)
        end
      end

      assert_match(/Fetching failed CI checks from GitHub for commit/, stdout)
      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/statuses")
    end

    def test_fetch_ci_checks_return_only_github_actions
      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
        .to_return_json(
          status: 200,
          body: {
            total_count: 2,
            check_runs: [
              { id: 1, name: "foo", conclusion: "success", app: { slug: "github-actions" } },
              { id: 1, name: "foo", conclusion: "success", app: { slug: "some_other_app" } },
            ],
          },
        )

      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/statuses")
        .to_return_json(status: 200, body: "[]")

      stdout, _ = capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          checks = TestRunFinder.fetch_ci_checks("catanacorp/catana", "abcdef")

          assert_equal(1, checks.count)
          assert_equal("catanacorp/catana", checks.first.repository)
          assert_equal("abcdef", checks.first.commit)
          assert_equal("foo", checks.first.name)
          assert_equal("success", checks.first.status)
          assert_equal(1, checks.first.id)
        end
      end

      assert_match(/Fetching failed CI checks from GitHub for commit/, stdout)
      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/statuses")
    end

    def test_fetch_ci_checks_fetch_commit_statuses
      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/statuses")
        .to_return_json(
          status: 200,
          body: JSON.dump(
            [
              { context: "ci/circleci: ruby-27", target_url: "https://circleci.com/gh/a/b/956", state: "success" },
              { context: "ci/circleci: ruby-30", target_url: "https://circleci.com/gh/a/b/957", state: "success" },
            ],
          ),
        )

      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
        .to_return_json(status: 200, body: { check_runs: [] })

      capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          checks = TestRunFinder.fetch_ci_checks("catanacorp/catana", "abcdef")

          assert_equal(2, checks.count)
          assert_equal("catanacorp/catana", checks.first.repository)
          assert_equal("abcdef", checks.first.commit)
          assert_equal("ci/circleci: ruby-27", checks.first.name)
          assert_equal("success", checks.first.status)
          assert_equal("https://circleci.com/gh/a/b/956", checks.first.url)

          assert_equal("catanacorp/catana", checks[1].repository)
          assert_equal("abcdef", checks[1].commit)
          assert_equal("ci/circleci: ruby-30", checks[1].name)
          assert_equal("success", checks[1].status)
          assert_equal("https://circleci.com/gh/a/b/957", checks[1].url)
        end
      end

      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/statuses")
    end

    def test_fetch_ci_checks_fetch_commit_status_and_remove_the_one_without_target_url
      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/statuses")
        .to_return_json(
          status: 200,
          body: JSON.dump(
            [
              { context: "ci/circleci: ruby-27", target_url: "https://circleci.com/gh/a/b/956", state: "success" },
              { context: "ci/circleci: ruby-30", target_url: nil, state: "success" },
            ],
          ),
        )

      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
        .to_return_json(status: 200, body: { check_runs: [] })

      capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          checks = TestRunFinder.fetch_ci_checks("catanacorp/catana", "abcdef")

          assert_equal(1, checks.count)
          assert_equal("catanacorp/catana", checks.first.repository)
          assert_equal("abcdef", checks.first.commit)
          assert_equal("ci/circleci: ruby-27", checks.first.name)
          assert_equal("success", checks.first.status)
          assert_equal("https://circleci.com/gh/a/b/956", checks.first.url)
        end
      end

      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/statuses")
    end

    def test_fetch_ci_checks_fetch_commit_statuses_and_checks
      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
        .to_return_json(
          status: 200,
          body: {
            total_count: 1,
            check_runs: [
              { id: 1, name: "foo", conclusion: "success", app: { slug: "github-actions" } },
            ],
          },
        )

      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/statuses")
        .to_return_json(
          status: 200,
          body: JSON.dump(
            [
              { context: "ci/circleci: ruby-27", target_url: "https://circleci.com/gh/a/b/956", state: "success" },
            ],
          ),
        )

      capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          checks = TestRunFinder.fetch_ci_checks("catanacorp/catana", "abcdef")

          assert_equal(2, checks.count)

          assert_equal("catanacorp/catana", checks.first.repository)
          assert_equal("abcdef", checks.first.commit)
          assert_equal("foo", checks.first.name)
          assert_equal("success", checks.first.status)
          assert_equal(1, checks.first.id)

          assert_equal("catanacorp/catana", checks[1].repository)
          assert_equal("abcdef", checks[1].commit)
          assert_equal("ci/circleci: ruby-27", checks[1].name)
          assert_equal("success", checks[1].status)
          assert_equal("https://circleci.com/gh/a/b/956", checks[1].url)
        end
      end

      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/statuses")
    end

    def test_fetch_ci_checks_when_checks_cant_be_retrieved
      stub_request(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
        .to_return(status: 404, body: "Not found")

      stdout, _ = capture_io do
        ::CLI::UI::StdoutRouter.with_enabled do
          TestRunFinder.fetch_ci_checks("catanacorp/catana", "abcdef") do
            puts "Couldn't retrieve CI checks"
          end
        end
      end

      assert_match("Couldn't retrieve CI checks", stdout)
      assert_requested(:get, "https://api.github.com/repos/catanacorp/catana/commits/abcdef/check-runs")
    end

    def test_find_when_the_run_failed
      ci_checks = [
        Check::Github.new("catanacorp/catana", "abcdef", "Test Ruby 3.0", "failure", 1),
        Check::Github.new("catanacorp/catana", "abcdef", "Test Ruby 3.1", "failure", 2),
      ]

      check_run = TestRunFinder.find(ci_checks, "Test Ruby 3.0")

      assert_equal(ci_checks.first, check_run)
    end

    def test_find_when_the_run_succeed
      ci_checks = [
        Check::Github.new("catanacorp/catana", "abcdef", "Test Ruby 2.7", "failure", 1),
        Check::Github.new("catanacorp/catana", "abcdef", "Test Ruby 3.0", "success", 2),
      ]

      error = assert_raises(Error) do
        TestRunFinder.find(ci_checks, "Test Ruby 3.0")
      end

      assert_equal(
        "The CI check 'Test Ruby 3.0' was successfull. There should be no failing tests to rerun.",
        error.message,
      )
    end

    def test_find_when_the_run_doesnt_exist
      ci_checks = [
        Check::Github.new("catanacorp/catana", "abcdef", "Test Ruby 2.7", "failure", 1),
        Check::Github.new("catanacorp/catana", "abcdef", "Test Ruby 3.0", "success", 2),
        Check::Github.new("catanacorp/catana", "abcdef", "Test Ruby 3.1", "cancelled", 3),
      ]

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
      ci_checks = []

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
