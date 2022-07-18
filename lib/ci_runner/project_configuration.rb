# frozen_string_literal: true

require "pathname"
require "yaml"
require "singleton"

module CIRunner
  class ProjectConfiguration
    include Singleton

    CONFIG_PATH = ".github/ci_runner.yml"

    def initialize
      @yaml_config = load!
    end

    def load!
      return {} unless config_file.exist?

      YAML.load_file(config_file)
    end

    private

    def config_file
      Pathname(File.expand_path(CONFIG_PATH, Dir.pwd))
    end
  end
end
