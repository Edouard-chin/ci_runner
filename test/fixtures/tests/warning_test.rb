# frozen_string_literal: true

require "minitest/autorun"

class WarningTest < Minitest::Test
  def test_right_gemfile_picked
    assert(Gem.loaded_specs.key?("warning"))
  end

  def test_default_gemfile_picked
    refute(Gem.loaded_specs.key?("warning"))
  end
end
