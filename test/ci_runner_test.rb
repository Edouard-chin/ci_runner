# frozen_string_literal: true

require "test_helper"

class CIRunnerTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::CIRunner::VERSION
  end

  def test_it_does_something_useful
    assert false
  end
end
