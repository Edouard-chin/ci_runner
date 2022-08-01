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
      @yaml_config = config_file.exist? ? YAML.load_file(config_file) : {}
    end

    def ruby_detection_regex
      to_regexp(@yaml_config.dig("ruby_regex"))
    end

    def gemfile_detection_regex
      to_regexp(@yaml_config.dig("gemfile_regex"))
    end

    def seed_detection_regex
      to_regexp(@yaml_config.dig("seed_regex"))
    end

    def buffer_starts_regex
      to_regexp(@yaml_config.dig("buffer_starts_regex"))
    end

    def process_on_new_match?
      value = @yaml_config.dig("seed_regex")

      value.nil? ? true : value
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
