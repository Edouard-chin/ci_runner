# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "fileutils"

module CIRunner
  class LogDownloader
    def initialize(commit, repository, run_name, shell)
      @commit = commit
      @repository = repository
      @run_name = run_name
      @shell = shell
    end

    def fetch
      if cached_log
        @shell.say("Logs for commit #{@commit} and CI run #{@run_name} retrieved from cache.", :green)

        return cached_log
      end

      github_client = GithubClient.new(Configuration.instance.github_token)
      check_runs = github_client.check_runs(@repository, @commit)
      check_run = TestRunFinder.find(@run_name, check_runs)

      @shell.say("Downloading CI logs, this can take a few seconds...", :green)

      logfile = github_client.download_log(@repository, check_run["id"])
      cache_log(logfile)

      cached_log
    end

    private

    def cache_log(logfile)
      FileUtils.mkdir_p(computed_file_path.dirname)

      FileUtils.cp(logfile, computed_file_path)
    end

    def computed_file_path
      normalized_run_name = @run_name.tr("/", "_")

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
