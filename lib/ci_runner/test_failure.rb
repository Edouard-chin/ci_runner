# frozen_string_literal: true

require "pathname"

module CIRunner
  class TestFailure
    attr_reader :klass, :test_name, :path

    def initialize(klass, test_name, path)
      @klass = klass
      @test_name = test_name
      @path = absolute_path(Pathname(path))
    end

    private

    def absolute_path(path)
      if path.relative?
        File.expand_path(path, Dir.pwd)
      end

      regex = /.*\/(test\/.*?)\Z/
      unless path.to_s.match?(regex)
        raise "Can't create a relative path."
      end

      File.expand_path(path.to_s.sub(regex, '\1'), Dir.pwd)
    end
  end
end
