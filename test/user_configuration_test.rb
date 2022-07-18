# frozen_string_literal: true

require "test_helper"

module CIRunner
  class UserConfigurationTest < Minitest::Test
    def setup
      UserConfiguration.instance.load!
    end

    def test_save_github_token
      UserConfiguration.instance.save_github_token("abcdef")

      expected = <<~EOM
        ---
        github:
          token: abcdef
      EOM

      assert_equal(expected, UserConfiguration.instance.config_file.read)
      assert_equal("abcdef", UserConfiguration.instance.github_token)
    end

    def test_github_token_when_not_set
      expected = <<~EOM
        --- {}
      EOM

      assert_equal(expected, UserConfiguration.instance.config_file.read)
      assert_nil(UserConfiguration.instance.github_token)
    end
  end
end
