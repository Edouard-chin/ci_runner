# frozen_string_literal: true

require "pathname"
require "yaml"
require "singleton"

module CIRunner
  class ProjectConfiguration
    include Singleton

    CONFIG_PATH = ".github/ci_runner.yml"

    def initialize
      load!
    end

    def load!
      @yaml_config = config_file.exist? ? YAML.safe_load_file(config_file, permitted_classes: [Regexp]) : {}
    end

    def ruby_detection_regex
      to_regexp(@yaml_config.dig("ruby_regex"))
    end

    def gemfile_detection_regex
      to_regexp(@yaml_config.dig("gemfile_regex"))
    end

    def config_file
      Pathname(File.expand_path(CONFIG_PATH, Dir.pwd))
    end

    private

    def to_regexp(value)
      value ? Regexp.new(value) : value
    end
  end
end
