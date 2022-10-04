# frozen_string_literal: true

require "test_helper"
require "json"

module CIRunner
  module Check
    class CircleCITest < Minitest::Test
      def setup
        @check = CircleCI.new(
          "owner/repo",
          "abcdef",
          "ci/circleci: ruby-27",
          "failure",
          "https://circleci.com/gh/owner/repo/3230?utm_campaign=vcs-integration-link",
        )
      end

      def test_download_log_makes_an_api_call_to_the_right_url
        stub_request(:get, "https://circleci.com/api/v1.1/project/github/owner/repo/3230")
          .to_return_json(status: 200, body: { steps: [] })

        @check.download_log

        assert_requested(:get, "https://circleci.com/api/v1.1/project/github/owner/repo/3230")
      end

      def test_download_log_downloads_the_log_output_for_each_step
        stub_request(:get, "https://circleci.com/api/v1.1/project/github/owner/repo/3230")
          .to_return_json(status: 200, body: read_fixture("circleci/job.json"))

        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/1")
          .to_return(status: 200, body: JSON.dump([message: "abc"]))
        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/2")
          .to_return(status: 200, body: JSON.dump([message: "def"]))
        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/3")
          .to_return(status: 200, body: JSON.dump([message: "ghi"]))
        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/4")
          .to_return(status: 200, body: JSON.dump([message: "jkl"]))
        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/5")
          .to_return(status: 200, body: JSON.dump([message: "mno"]))

        file = @check.download_log
        file.rewind
        file_content = file.read

        assert_match("abc", file_content)
        assert_match("def", file_content)
        assert_match("ghi", file_content)
        assert_match("jkl", file_content)
        assert_match("mno", file_content)

        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/1")
        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/2")
        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/3")
        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/4")
        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/5")
      end

      def test_download_log_skip_steps_without_output
        stub_request(:get, "https://circleci.com/api/v1.1/project/github/owner/repo/3230")
          .to_return_json(status: 200, body: read_fixture("circleci/job_step_no_output.json"))

        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/1")
          .to_return(status: 200, body: JSON.dump([message: "abc"]))
        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/3")
          .to_return(status: 200, body: JSON.dump([message: "ghi"]))
        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/4")
          .to_return(status: 200, body: JSON.dump([message: "jkl"]))
        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/5")
          .to_return(status: 200, body: JSON.dump([message: "mno"]))

        file = @check.download_log
        file.rewind
        file_content = file.read

        assert_match("abc", file_content)
        assert_match("ghi", file_content)
        assert_match("jkl", file_content)
        assert_match("mno", file_content)

        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/1")
        refute_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/2")
        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/3")
        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/4")
        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/5")
      end

      def test_download_log_when_steps_run_in_parallel
        stub_request(:get, "https://circleci.com/api/v1.1/project/github/owner/repo/3230")
          .to_return_json(status: 200, body: read_fixture("circleci/job_parallel.json"))

        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/1")
          .to_return(status: 200, body: JSON.dump([message: "abc"]))
        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/3")
          .to_return(status: 200, body: JSON.dump([message: "ghi"]))
        stub_request(:get, "https://circle-production-action-output.s3.amazonaws.com/4")
          .to_return(status: 200, body: JSON.dump([message: "jkl"]))

        file = @check.download_log
        file.rewind
        file_content = file.read

        assert_match("abc", file_content)
        assert_match("ghi", file_content)
        assert_match("jkl", file_content)

        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/1")
        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/3")
        assert_requested(:get, "https://circle-production-action-output.s3.amazonaws.com/4")
      end

      def test_failed_is_true_when_status_is_failure
        assert_predicate(@check, :failed?)
      end

      def test_failed_is_true_when_status_is_error
        check = CircleCI.new(
          "owner/repo",
          "abcdef",
          "ci/circleci: ruby-27",
          "error",
          "https://circleci.com/gh/owner/repo/3230?utm_campaign=vcs-integration-link",
        )

        assert_predicate(check, :failed?)
      end

      def test_failed_is_false
        check = CircleCI.new(
          "owner/repo",
          "abcdef",
          "ci/circleci: ruby-27",
          "success",
          "https://circleci.com/gh/owner/repo/3230?utm_campaign=vcs-integration-link",
        )

        refute_predicate(check, :failed?)
      end
    end
  end
end
