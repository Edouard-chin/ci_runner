# frozen_string_literal: true

require "drb/drb"
require "ci_runner/suite"

module Minitest
  extend self

  def plugin_ci_runner_options(opts, options)
    opts.on "--ci-runner", "Inform CIRunner to use this plugin" do |value|
      options[:ci_runner] = value
    end
  end

  def plugin_ci_runner_init(options)
    return unless options[:ci_runner]

    DRb.start_service
    bla = DRbObject.new_with_uri("druby://localhost:8787")

    options[:filter] = CIRunner::Suite.new(bla.failures)
  end
end
