# frozen_string_literal: true

require "pathname"
require "yaml"
require "singleton"

module CIRunner
  class UserConfiguration
    include Singleton

    USER_CONFIG_PATH = ".ci_runner/config.yml"

    def initialize
      @yaml_config = load!
    end

    def load!
      save!({}) unless config_file.exist?

      YAML.load_file(config_file)
    end

    def github_token
      @yaml_config["github"]["token"]
    end

    def save_github_token(token)
      @yaml_config["github"] = { "token" => token }

      save!(@yaml_config)
    end

    private

    def save!(config = {})
      raise(Error, "Your home directory is not writeable") unless Pathname(Dir.home).writable?

      dir = config_file.dirname
      dir.mkdir unless dir.exist?

      File.write(config_file, YAML.dump(config))
    end

    def config_file
      Pathname(File.expand_path(USER_CONFIG_PATH, Dir.home))
    end
  end
end
