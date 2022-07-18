# frozen_string_literal: true

require "test_helper"

module CIRunner
  class CLITest < Minitest::Test
    def setup
      UserConfiguration.instance.load!

      super
    end

    def test_github_token_when_token_is_valid
      stub_request(:get, "https://api.github.com/user")
        .to_return_json(status: 200, body: { login: "Bob" })

      stdout, _ = capture_io do
        CLI.start(%w(github_token blabla))
      end

      expected_output = "Hello Bob! Your token has been saved successfully!\n"
      assert_equal(expected_output, stdout)

      expected_config = <<~EOM
        ---
        github:
          token: blabla
      EOM

      assert_equal(expected_config, UserConfiguration.instance.config_file.read)
    end

    def test_github_token_when_token_is_invalid
      stub_request(:get, "https://api.github.com/user")
        .to_return_json(status: 401, body: "Requires authentication")

      _, stderr = capture_io do
        CLI.start(%w(github_token blabla))
      end

      expected = <<~EOM
        Your token doesn't seem to be valid. The response from GitHub was:

        Requires authentication
      EOM

      assert_equal(expected, stderr)

      expected_config = <<~EOM
        --- {}
      EOM

      assert_equal(expected_config, UserConfiguration.instance.config_file.read)
    end
  end
end
