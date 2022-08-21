# frozen_string_literal: true

require "test_helper"

module CIRunner
  module Runners
    class RSpecTest < Minitest::Test
      def test_parse_return_failures
        runner = RSpec.new(read_fixture("rspec.log"))
        runner.parse!

        expected_test_name = "Octokit::Client::Repositories.edit_repository is_template is passed in params gets"
        expected = TestFailure.new(nil, expected_test_name, "./spec/octokit/client/repositories_spec.rb")

        assert_equal(1, runner.failures.count)
        assert_nil(runner.failures[0].klass)
        assert_equal(expected.test_name, runner.failures[0].test_name)
        assert_equal(expected.path, runner.failures[0].path)
      end

      def test_parse_return_failures_when_output_is_colored
        runner = RSpec.new(read_fixture("rspec_colored.log"))
        runner.parse!

        expected_test_name = "customer edit page displays selectable strings as dropdowns"
        expected = TestFailure.new(nil, expected_test_name, "./spec/features/edit_page_spec.rb")

        assert_equal(1, runner.failures.count)
        assert_nil(runner.failures[0].klass)
        assert_equal(expected.test_name, runner.failures[0].test_name)
        assert_equal(expected.path, runner.failures[0].path)
      end

      def test_run_one_example
        runner = RSpec.new(nil)
        runner.seed = "1234"
        runner.failures = [
          TestFailure.new(nil, "harry potter abracadabra transforms", "test/fixtures/specs/foo_spec.rb"),
        ]

        stdout, _ = capture_io do
          runner.start!
        end

        assert_equal(<<~EOM, clean_statistics(stdout))
          Run options: include {:full_description=>/harry\\ potter\\ abracadabra\\ transforms/}

          Randomized with seed 1234
          .

          Finished in 0s.
          1 example, 0 failures

          Randomized with seed 1234

        EOM
      end

      def test_run_two_examples
        runner = RSpec.new(nil)
        runner.seed = "1817"
        runner.failures = [
          TestFailure.new(nil, "harry potter abracadabra transforms", "test/fixtures/specs/foo_spec.rb"),
          TestFailure.new(nil, "harry potter abracadabra flies", "test/fixtures/specs/foo_spec.rb"),
        ]

        stdout, _ = capture_io do
          runner.start!
        end

        assert_equal(<<~EOM, clean_statistics(stdout))
          Run options: include {:full_description=>/(?-mix:harry\\ potter\\ abracadabra\\ transforms)|(?-mix:harry\\ potter\\ abracadabra\\ flies)/}

          Randomized with seed 1817
          ..

          Finished in 0s.
          2 examples, 0 failures

          Randomized with seed 1817

        EOM
      end

      def test_run_two_suites
        runner = RSpec.new(nil)
        runner.seed = "1817"
        runner.failures = [
          TestFailure.new(nil, "harry potter abracadabra transforms", "test/fixtures/specs/foo_spec.rb"),
          TestFailure.new(nil, "hermione abracadabra flies", "test/fixtures/specs/bla_spec.rb"),
        ]

        stdout, _ = capture_io do
          runner.start!
        end

        assert_equal(<<~EOM, clean_statistics(stdout))
          Run options: include {:full_description=>/(?-mix:harry\\ potter\\ abracadabra\\ transforms)|(?-mix:hermione\\ abracadabra\\ flies)/}

          Randomized with seed 1817
          ..

          Finished in 0s.
          2 examples, 0 failures

          Randomized with seed 1817

        EOM
      end

      private

      def clean_statistics(string)
        regex = /(Finished in) .*/

        string.gsub(regex, '\1 0s.')
      end
    end
  end
end
