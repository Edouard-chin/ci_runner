# frozen_string_literal: true

require_relative "base"

module CIRunner
  module Runners
    class RSpec < Base
      def self.match?(log)
        command = /bundle exec rspec/
        summary = /Failed examples:/

        Regexp.union(command, summary, /rspec/i).match?(log)
      end

      def name
        "RSpec"
      end

      def parse!
        @ci_log.each_line do |line|
          case line
          when /Randomized with seed[[:blank:]]*(\d+)/
            @seed = Regexp.last_match(1)
          when /[^_-][rR]uby(?:[[:blank:]]*|\/)(\d\.\d\.\d+)p?(?!\/gems)/
            @ruby_version = Regexp.last_match(1)
          when /BUNDLE_GEMFILE:[[:blank:]]*(.*)/
            @gemfile = Regexp.last_match(1).rstrip
          when /(Finished in|Failed examples)/
            @buffer << line
          else
            @buffer << line if buffering?
          end
        end

        process_buffer if buffering?
      end

      def start!
        super

        flags = failures.map { |failure| "--example '#{failure.test_name}'" }.join(" ")
        flags << " --seed #{seed}" if seed

        code = <<~EOM
          require 'rspec/core/rake_task'

          RSpec::Core::RakeTask.new('__ci_runner_test') do |task|
            task.pattern = #{failures.map(&:path)}
            task.rspec_opts = "#{flags}"
            task.verbose = false
          end

          Rake::Task[:__ci_runner_test].invoke
        EOM

        dir = Dir.mktmpdir
        rakefile_path = File.expand_path("Rakefile", dir)

        File.write(rakefile_path, code)

        env = {}
        env["RUBY"] = ruby_path.to_s if ruby_path && ruby_path.exist?
        env["BUNDLE_GEMFILE"] = gemfile_path.to_s if gemfile_path && gemfile_path.exist?

        system(env, "bundle exec ruby #{rakefile_path}")
      end

      private

      def process_buffer
        failure_regex = %r{rspec[[:blank:]]*(?<file_path>.*?):\d+[[:blank:]]*#[[:blank:]]*(?<test_name>.*)}

        @buffer.each_line do |line|
          line.match(failure_regex) do |match_data|
            @failures << TestFailure.new(nil, match_data[:test_name].rstrip, match_data[:file_path])
          end
        end
      end
    end
  end
end
