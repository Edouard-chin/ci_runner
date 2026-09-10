# frozen_string_literal: true

require "drb/drb"

module Minitest
  extend self

  def plugin_ci_runner_options(opts, options)
    opts.on("--ci-runner=URI", "The UNIX socket CI Runner needs to connect to") do |value|
      options[:ci_runner] = value
    end
  end

  def plugin_ci_runner_init(options)
    return unless options[:ci_runner]

    options[:args].gsub!(/\s*--ci-runner=#{options[:ci_runner]}\s*/, "")

    DRb.start_service
    failures = DRbObject.new_with_uri(options[:ci_runner])

    filter = Struct.new(:failures) do
      def ===(runnable)
        failures.any? do |failure|
          "#{failure.klass}##{failure.test_name}" == runnable
        end
      end

      # Vanilla Minitest filters with `filter === runnable`, but the minitest-reporters gem's
      # DelegateReporter calls `filter.match?(runnable)` instead. Alias the two so CI Runner
      # works whether or not the project under test uses minitest-reporters.
      alias_method :match?, :===
    end

    options[:filter] = filter.new(failures)
  end
end
