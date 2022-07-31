# frozen_string_literal: true

require "minitest/autorun"

module SomeFolder
  class BarTest < Minitest::Test
    def test_one
      raise
    end

    def test_two
      assert(true)
      assert(true)
      assert(true)
      assert(true)
    end

    def test_should_never_run
      raise
    end
  end
end
