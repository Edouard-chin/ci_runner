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

          assert_equal({ "total_count" => 1, "check_runs" => [{ "id" => 1, "name" => "foo" }]}, checks)
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
          TestRunFinder.fetch_ci_checks("canatacorp/catana", "abcdef") do |error|
            puts "Couldn't retrieve CI checks"
          end
        end
      end

      assert_match("Couldn't retrieve CI checks", stdout)
      assert_requested(:get, "https://api.github.com/repos/canatacorp/catana/commits/abcdef/check-runs")
    end
  end
end
