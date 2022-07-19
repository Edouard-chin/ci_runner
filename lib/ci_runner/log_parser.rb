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
      buffer = +""

      @log_content.each_line do |line|
        case line
        when /Run options:.*?--seed\s+(\d+)/ # <== Default minitest log
          @seed = Regexp.last_match(1).to_i
        when /Running tests with run options.*--seed\s+(\d+)/ # <== Minitest-reporter log
          @seed = Regexp.last_match(1).to_i
        when /(Failure|Error):\s*\Z/
          process_buffer(buffer) unless buffer.empty?
          buffer.clear
          buffer << line
        else
          buffer << line unless buffer.empty?
        end
      end

      process_buffer(buffer) unless buffer.empty?
    end

    private

    def process_buffer(buffer)
      match_data = minitest_failure(buffer)
      return unless match_data

      file_path = valid_path?(match_data[:file_path]) ? match_data[:file_path] : find_test_location(buffer, match_data)

      @failures << TestFailure.new(match_data[:class], match_data[:test_name], file_path)
    end

    def valid_path?(path)
      return false if path.nil?

      points_to_a_gem = %r{ruby/.*?/gems}

      !path.match?(points_to_a_gem)
    end

    def find_test_location(buffer, match_data)
      match = try_rails(buffer)
      return match if match

      match = try_infer_file_from_class(buffer, match_data)
      return match if match

      match = try_stacktrace(buffer, match_data)
      return match if match

      raise("Can't find test location")
    end

    def underscore(camel_cased_word)
      return camel_cased_word.to_s unless /[A-Z-]|::/.match?(camel_cased_word)
      word = camel_cased_word.to_s.gsub("::", "/")

      word.gsub!(/([A-Z]+)(?=[A-Z][a-z])|([a-z\d])(?=[A-Z])/) { ($1 || $2) << "_" }
      word.tr!("-", "_")
      word.downcase!
      word
    end

    def try_stacktrace(buffer, match_data)
      regex = /\s*(\/.*?):\d+:in.*#{match_data[:class]}/

      buffer.match(regex) { |match| match[1] }
    end

    def try_infer_file_from_class(buffer, match_data)
      file_name = underscore(match_data[:class])
      regex = /(\/.*#{file_name}.*?):\d+/

      buffer.match(regex) { |match| match[1] }
    end

    def try_rails(buffer)
      regex = /rails\s+test\s+(.*?):\d+/

      buffer.match(regex) { |match| match[1] }
    end

    def minitest_failure(buffer)
      regex = /(?:\s*)(?<class>[a-zA-Z0-9_:]+)\#(?<test_name>test_.+?)(:\s*$|\s+\[(?<file_path>.*):\d+\])/

      regex.match(buffer)
    end
  end
end
