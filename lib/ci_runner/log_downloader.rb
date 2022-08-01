# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "fileutils"

module CIRunner
  class LogDownloader
    def initialize(commit, repository, check_run)
      @commit = commit
      @repository = repository
      @check_run = check_run
    end

    def fetch(&block)
      return cached_log if cached_log

      github_client = GithubClient.new(Configuration::User.instance.github_token)
      error = nil

      ::CLI::UI.spinner("Downloading CI logs from GitHub", auto_debrief: false) do |spinner|
        logfile = github_client.download_log(@repository, @check_run["id"])

        cache_log(logfile)
      rescue GithubClient::Error => e
        error = e

        ::CLI::UI::Spinner::TASK_FAILED
      end

      block.call(error) if error
      cached_log
    end

    private

    def cache_log(logfile)
      FileUtils.mkdir_p(computed_file_path.dirname)

      if logfile.is_a?(Tempfile)
        FileUtils.cp(logfile, computed_file_path)
      else
        File.write(computed_file_path, logfile.read)
      end
    end

    def computed_file_path
      normalized_run_name = @check_run["name"].tr("/", "_")

      log_folder.join("log-#{@commit[0..12]}-#{normalized_run_name}.log")
    end

    def log_folder
      Pathname(Dir.tmpdir).join(@repository)
    end

    def cached_log
      return false unless computed_file_path.exist?

      computed_file_path
    end
  end
end
