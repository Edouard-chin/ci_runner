# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ci_runner"

require "minitest/autorun"
require "webmock/minitest"
require "fileutils"

module Minitest
  class Test
    def before_setup
      @home_dir = Dir.mktmpdir
      ENV["HOME"] = @home_dir
      ENV["TMPDIR"] = @home_dir

      super
    end

    def after_teardown
      super

      FileUtils.rm_rf(@home_dir) if @home_dir
    end

    def read_fixture(file)
      fixture_folder = Pathname(File.expand_path("fixtures", __dir__))
      fixture_path = fixture_folder.join(file)

      raise("Fixture file #{file} does not exist (searched in #{fixture_path})") unless fixture_path.exist?

      fixture_path
    end
  end
end

# Patch CLI UI winsize. Otherwise the output depends on the terminal size which breaks
# some tests.
module PatchedTerminal
  def winsize
    [24, 120]
  end
end

::CLI::UI::Terminal.singleton_class.prepend(PatchedTerminal)
::CLI::UI.enable_color = true
