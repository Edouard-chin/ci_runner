# frozen_string_literal: true

module CIRunner
  class Suite
    def initialize(failures)
      @failures = failures
    end

    def ===(runnable)
      @failures.any? do |failure|
        "#{failure.klass}##{failure.test_name}" == runnable
      end
    end
  end
end
