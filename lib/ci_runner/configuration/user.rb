# frozen_string_literal: true

require "pathname"
require "yaml"
require "singleton"

module CIRunner
  module Configuration
    # Class to interact with the user's configuration. The configuration is used
    # to store the GitHub token amonst other things.
    #
    # @param Use this configuration
    #   User.instance.github_token
    class User
      include Singleton

      USER_CONFIG_PATH = ".ci_runner/config.yml"

      # Singleton class. This should/can't be called directly.
      #
      # @return [void]
      def initialize
        load!
      end

      # Load the configuration of the user. If it doesn't exist, write an empty one.
      #
      # @return [void]
      def load!
        save!({}) unless config_file.exist?

        @yaml_config = YAML.load_file(config_file)
      end

      # Retrieve the stored GitHub access token of the user.
      #
      # @return [String, nil] Depending if the user ran the `ci_runner github_token TOKEN` command.
      def github_token
        @yaml_config.dig("github", "token")
      end

      # Retrieve the stored CircleCI access token of the user.
      #
      # @return [String, nil] Depending if the user ran the `ci_runner circle_ci_token TOKEN` command.
      def circle_ci_token
        @yaml_config.dig("circle_ci", "token")
      end

      # Write the GitHub token to the user configuration file
      #
      # @param token [String] A valid GitHub access token.
      #
      # @return [void]
      def save_github_token(token)
        @yaml_config["github"] = { "token" => token }

        save!(@yaml_config)
      end

      # Write the Circle CI token to the user configuration file
      #
      # @param token [String] A valid Circle CI access token.
      #
      # @return [void]
      def save_circle_ci_token(token)
        @yaml_config["circle_ci"] = { "token" => token }

        save!(@yaml_config)
      end

      # @return [Pathname] The path of the configuration file.
      #
      # @example
      #   puts config_file # ~/.ci_runner/config.yml
      def config_file
        Pathname(File.expand_path(USER_CONFIG_PATH, Dir.home))
      end

      # Ensure the user ran the `ci_runner github_token TOKEN` command prior to using CI Runner.
      #
      # Note: Technically, it's possible to access the GitHub API to retrieve checks and download logs on
      # public repositories, but on private repositories the error GitHub sends back is a 404 which can
      # be confusing, so I'd rather just make sure the token exists either way.
      #
      # @raise [Error] If the user tries to run `ci_runner rerun` before it saved a token in its config file.
      #
      # @return [void]
      def validate_token!
        return if github_token

        raise(Error, <<~EOM)
          A GitHub token needs to be saved into your configuration before being able to use CI Runner.

          Have a look at the {{command:ci_runner help github_token}} command.
        EOM
      end

      private

      # Dump into yaml and store the new configuration to the +config_file+.
      #
      # @param config [Hash] A hash that will be dumped to YAML.
      #
      # @raise [Error] In the case where the user's home directory is not writeable (hello nix).
      def save!(config = {})
        raise(Error, "Your home directory is not writeable") unless Pathname(Dir.home).writable?

        dir = config_file.dirname
        dir.mkdir unless dir.exist?

        File.write(config_file, YAML.dump(config))
      end
    end
  end
end
