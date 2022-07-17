# frozen_string_literal: true

require "minitest/autorun"

class FooTest < Minitest::Test
  def test_one
    assert(true)
  end

  def test_two
    assert(true)
  end

  def test_should_never_run
    boom
  end
end
