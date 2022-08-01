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
    end
  end
end
