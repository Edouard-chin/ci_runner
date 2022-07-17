# frozen_string_literal: true

require "test_helper"

module CIRunner
  module Configuration
    class UserTest < Minitest::Test
      def setup
        Configuration::User.instance.load!
      end

      def test_save_github_token
        Configuration::User.instance.save_github_token("abcdef")

        expected = <<~EOM
          ---
          github:
            token: abcdef
        EOM

        assert_equal(expected, Configuration::User.instance.config_file.read)
        assert_equal("abcdef", Configuration::User.instance.github_token)
      end

      def test_github_token_when_not_set
        expected = <<~EOM
          --- {}
        EOM

        assert_equal(expected, Configuration::User.instance.config_file.read)
        assert_nil(Configuration::User.instance.github_token)
      end
    end
  end
end
