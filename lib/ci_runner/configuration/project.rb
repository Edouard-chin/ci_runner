# frozen_string_literal: true

require "pathname"
require "yaml"
require "singleton"

module CIRunner
  module Configuration
    # A class to interact with a project's Configuration.
    #
    # CI Runner tries its best to come out of the box functional. It comes bundled with a set
    # of regexes that detects variety of output. For instance if your project uses RSpec or Minitest
    # AND you haven't modified their reporters, CI Runner should just work with no extra setup.
    #
    # However, if your application or Gem has custom reporters, CI Runner set of regexes won't work, as the output
    # expected will change because of those custom reporters.
    # CI Runner allows to change those regexes thanks to a configuration file you can store on each of your project.
    #
    # Note that all *_regex configuration value can be either a String or a Serialized Regexp object.
    #
    # @example Using a String
    #   ---
    #   ruby_regex: "Ruby v(\\d\\.\\d\\.\\d)" ==> Note that each backslash has to be escaped!
    #
    # @example Using a serialized Regexp
    #   ---
    #   ruby_regex: !ruby/regexp "/Ruby v(\\d\\.\\d\\.\\d)/m" ==> Convenient if you need to have flags on the regex.
    #
    # @see https://yaml.org/YAML_for_ruby.html#regexps
    class Project
      include Singleton

      CONFIG_PATH = ".github/ci_runner.yml"

      # Singleton class. Shouldn't/Can't be called directly. Call Project.instance instead.
      #
      # @return [void]
      def initialize
        load!
      end

      # Load the configuration file from the project into memory.
      #
      # @return [void]
      def load!
        @yaml_config = config_file.exist? ? YAML.safe_load(config_file.read, permitted_classes: [Regexp]) : {}
      end

      # This regex is used to detect the Ruby version that was used on a CI. It's quite common to have a CI
      # testing a gem on different version of Ruby.
      # If detected, CI Runner will use that same Ruby version from your machine (if it exists) to run the test suite.
      #
      # **Important**. Your regex has to contain ONE capturing match, being the Ruby version itself.
      #
      # @return [nil, Regexp] Depending if the project has set this. CI Runner default will be used when not set.
      #
      # @example Storing this configuration
      #   `cat myproject/.github/ci_runner.yml`
      #
      #   ---
      #   ruby_regex: "Ruby (.*)"
      def ruby_detection_regex
        to_regexp(@yaml_config.dig("ruby_regex"))
      end

      # This regex is used to detect the Gemfile version that was used on a CI. It's quite common to have a CI
      # testing a gem with different set of dependencies thanks to multiple Gemfiles.
      # If detected, CI Runner will use the same Gemfile from your machine (if it exists) to run the test suite.
      #
      # **Important**. Your regex has to contain ONE capturing match, being the Gemfile path.
      #
      # @return [nil, Regexp] Depending if the project has set this. CI Runner default will be used when not set.
      #
      # @example Storing this configuration
      #   `cat myproject/.github/ci_runner.yml`
      #
      #   ---
      #   gemfile_regex: "Using GEMFILE: (.*)"
      def gemfile_detection_regex
        to_regexp(@yaml_config.dig("gemfile_regex"))
      end

      # This regex is used to detect the SEED on a CI. CI Runner aims to rerun failing tests on your machine
      # exactly the same as how it ran on CI, therefore in the same order. The SEED is what determine the order.
      #
      # **Important**. Your regex has to contain ONE capturing match, being the SEED value.
      #
      # @return [nil, Regexp] Depending if the project has set this. CI Runner default will be used when not set.
      #
      # @example Storing this configuration
      #   `cat myproject/.github/ci_runner.yml`
      #
      #   ---
      #   seed_regex: "Running with test options: --seed(.*)"
      def seed_detection_regex
        to_regexp(@yaml_config.dig("seed_regex"))
      end

      # This regex is used to tell CI Runner when to start buffering. The failures will then be matched
      # agains this buffer rather than the whole log output. An example to better understand:
      #
      # @return [nil, Regexp] Depending if the project has set this. CI Runner default will be used when not set.
      #
      # @example
      #   An RSpec output looks like this:
      #
      #      1.2) Failure/Error: @client.delete_repository(@repo.full_name)
      #
      #           NoMethodError:
      #             undefined method `full_name' for nil:NilClass
      #           # ./spec/octokit/client/repositories_spec.rb:71:in `block (3 levels) in <top (required)>'
      #           # ./.bundle/gems/ruby/3.0.0/gems/webmock-3.14.0/lib/webmock/rspec.rb:37:in `block (2 levels) in'
      #
      #   Finished in 26.53 seconds (files took 1.26 seconds to load)
      #   854 examples, 1 failure
      #
      #   Failed examples:
      #
      #   rspec ./spec/octokit/client/repository_spec.rb:75 # Octokit::Client::Repositories.edit_repository is_template
      #
      #   =====================
      #
      #   If you have this configuration set to "Failed examples:". CI Runner will start collecting test failures
      #   only after the "Failed examples" line appear.
      #
      # @example Storing this configuration
      #   `cat myproject/.github/ci_runner.yml`
      #
      #   ---
      #   buffer_starts_regex: "Failed examples:"
      def buffer_starts_regex
        to_regexp(@yaml_config.dig("buffer_starts_regex"))
      end

      # This is to be used in conjuction with the +buffer_starts_regex+. It accepts a boolean value.
      #
      # This configuration tells CI Runner to process the buffer and find failures each time a new line matching
      # +buffer_starts_regex+ appears.
      #
      # To detect the file path of each failing test, we have to go through  the stacktrace of each failing tests.
      #
      # When you set the `process_on_new_match` value to true (the default), your regex +test_failure_detection_regex+
      # will be matched agains each erroring test.
      #
      # @return [nil, Regexp] Depending if the project has set this. True by default.
      #
      # @example A Minitest failure output looks like this:
      #
      #   Finished in 0.015397s, 2013.4301 runs/s, 58649.2703 assertions/s.
      #
      #   Error:
      #
      #   TestReloading#test_reload_recovers_from_name_errors__w__on_unload_callbacks_:
      #   Tasks: TOP => default => test
      #   NameError: uninitialized constant X
      #   (See full trace by running task with --trace)
      #
      #     parent.const_get(cname, false)
      #           ^^^^^^^^^^
      #     /Users/runner/work/zeitwerk/zeitwerk/lib/zeitwerk/loader/helpers.rb:118:in
      #     /Users/runner/work/zeitwerk/zeitwerk/lib/zeitwerk/loader/helpers.rb:118:
      #     /Users/runner/work/zeitwerk/zeitwerk/test/lib/zeitwerk/test_reloading.rb:223:in `block (2 levels) in
      #
      #   Error:
      #
      #   OtherTest#test_something_else
      #   Tasks: TOP => default => test
      #   NameError: Boom
      #   (See full trace by running task with --trace)
      #
      #     bla.foo
      #         ^^^
      #   /Users/runner/work/zeitwerk/zeitwerk/test/lib/zeitwerk/other_test.rb:18:in
      #
      # @example Storing this configuration
      #   `cat myproject/.github/ci_runner.yml`
      #
      #   ---
      #   process_on_new_match: false
      def process_on_new_match?
        value = @yaml_config.dig("process_on_new_match")

        value.nil? ? true : value
      end

      # Main detection regex used to detect test failures.
      #
      # **Important** This regexp 3 named capture groups. The order doesn't matter.
      #
      # - "file_path"
      # - "test_name"
      # - "class"
      #
      # Your regex should look something like: /(?<file_path>...)(?<test_name>...)(?<class>...)/
      #
      # @return [nil, Regexp] Depending if the project has set this. CI Runner default will be used when not set.
      #
      # @raise [Error] If the provided doesn't have the 3 capturing group mentioned.
      #
      # @example Storing this configuration
      #   `cat myproject/.github/ci_runner.yml`
      #
      #   ---
      #   failure_regex: "your_regex"
      def test_failure_detection_regex
        regexp = to_regexp(@yaml_config.dig("failures_regex"))
        return unless regexp

        expected_captures = ["file_path", "test_name", "class"]
        difference = expected_captures - regexp.names

        if difference.any?
          raise(Error, <<~EOM)
            The {{warning:failures_regex}} configuration of your project doesn't include expected named captures.
            CI Runner expects the following Regexp named captures: #{expected_captures.inspect}.

            Your Regex should look something like {{info:/(?<file_path>...)(?<test_name>...)(?<class>...)/}}
          EOM
        end

        regexp
      end

      # @return [Pathname] The path of the configuration file.
      #
      # @example
      #   puts Project.instance.config_file # => project/.github/ci_runner.yml
      def config_file
        Pathname(File.expand_path(CONFIG_PATH, Dir.pwd))
      end

      private

      # @param value [String, Regexp, nil]
      #
      # @return [Regexp, nil]
      def to_regexp(value)
        value ? Regexp.new(value) : value
      end
    end
  end
end
