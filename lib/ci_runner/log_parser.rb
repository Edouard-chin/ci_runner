# frozen_string_literal: true

module CIRunner
  class LogParser
    attr_reader :failures, :seed

    def initialize(file)
      @log_content = file.read
      @failures = []
      @seed = nil
    end

    def parse
      parse_seed
      parse_failures
    end

    private

    def parse_seed
      @log_content.match(/Run options:.*?--seed\s+(\d+)/) do |match_data|
        @seed = match_data[1].to_i
      end
    end

    def parse_failures
      @log_content.scan(minitest_default_regex) do |result|
        @failures << TestFailure.new(*result)
      end
    end

    def minitest_default_regex
      %r{
        Failure:\s+          # Match "Failure \n" literally.
      (?:                  # Start of Non capturing group.
        \S*\s+               # Match any possible timestamp before the class definition.
      )                    # End of Non capturing group.
      (?<class>            # Start of named capturing group "class".
        [a-zA-Z0-9_:]+       # Match the name of the suite (i.e. BlablaControllerTest).
      )                    # End of named capturing group "class".
      \#                    # Match the "#" sign, literally.
      (?<test_name>        # Start of named capturing group "test_name".
        test_.*?             # Match the name of the test (i.e. test_works_correctly).
      )                    # End of named capturing group "test_name".
      \s+                  # Match empty space(s).
      \[
        (?<file_path>.*?)
        :\d+
      \]
      }x
    end
  end
end
