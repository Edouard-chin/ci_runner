# frozen_string_literal: true

module Minitest
  extend self

  def plugin_ci_runner_init(options)
    options[:filter] = CIRunner::Suite.new(CIRunner::TestRunner.failures)
  end
end
