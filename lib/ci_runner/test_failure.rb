# frozen_string_literal: true

require "pathname"
require "drb/drb"

module CIRunner
  # A container object to gather test failures as we parse the CI log output.
  class TestFailure
    # @see minitest/ci_runner_plugin.rb to understand why we need DRb.
    include DRbUndumped

    # @return [String] The name of the class that included the failing test.
    #
    # @example Given a output log: "TestReloading#test_reload_recovers_from_name_errors__w__on_unload_callbacks".
    #  puts klass # => TestReloading
    attr_reader :klass

    # @return [String] The name of the test that failed.
    #
    # @example Given a output log: "TestReloading#test_reload_recovers_from_name_errors__w__on_unload_callbacks".
    #  puts test_name # => test_reload_recovers_from_name_errors__w__on_unload_callbacks
    attr_reader :test_name

    # @return [String] The file location where this +klass+ lives.
    attr_reader :path

    # @param klass (See #klass)
    # @param test_name (See #test_name)
    # @param path (See #path)
    def initialize(klass, test_name, path)
      @klass = klass
      @test_name = test_name
      @path = absolute_path(Pathname(path))
    end

    private

    # Transform the path parsed from the log to make it absolute. CI Runner will run the tests from a temporary
    # folder on the user's machine, a relative path wouldn't work.
    #
    # Note: This method does another thing which is hacky and try to use the equivalent of `File.relative_path_from`.
    # See the example below.
    #
    # @param path [String] A absolute or relative path.
    #
    # @return [String] An absolute path based on where the user ran the `ci_runner` command.
    #
    # @example Trying to hack relative_path_from
    #   Given a log output from CI: "BlablaTest#test_abc [/home/runner/work/project/project/test/blabla.rb:7]:"
    #   Minitest outputs absolute path, we need to detect what portion is the home of the CI from the rest.
    #   For now using `test/` as that's usually where the Minitest tests are stored but it's likely that it would fail.
    def absolute_path(path)
      if path.relative?
        return File.expand_path(path, Dir.pwd)
      end

      regex = %r{.*/?(test/.*?)\Z}
      unless path.to_s.match?(regex)
        # TODO(on: '2022-09-17', to: "edouard-chin") Revisit this as it's too brittle.
        #   If a test file doesn't live the in the `test/` root folder, this will raise an error.
        #   I should instead warn the user and move on.
        raise "Can't create a relative path."
      end

      File.expand_path(path.to_s.sub(regex, '\1'), Dir.pwd)
    end
  end
end
