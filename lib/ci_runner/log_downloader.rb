# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "fileutils"

module CIRunner
  # A PORO to help download and cache a GitHub CI log.
  #
  # @example Using the service
  #   log_dl = LogDownloader.new("commit_sha", "catanacorp/catana", { "id" => 1, "name" => "Ruby Test 3.1.2" })
  #   log_file = log_dl.fetch
  #   puts log_file # => File
  #
  # @see https://docs.github.com/en/rest/actions/workflow-jobs#download-job-logs-for-a-workflow-run
  class LogDownloader
    # @param commit [String] A Git commit. Used to compute the file name we are going to cache.
    # @param repository [String] The repository full name, including the owner (i.e. rails/rails).
    # @param check_run [Hash] A GitHub CI check for which we want to download the log.
    def initialize(commit, repository, check_run)
      @commit = commit
      @repository = repository
      @check_run = check_run
    end

    # Download the CI logs from GitHub or retrieve it from disk in case we previously downloaded it.
    #
    # @param block [Proc, Lambda] A proc that gets called if fetching the logs from GitHub fails. Allows the CLI to
    #   prematurely exit while cleaning up the CLI::UI frame.
    #
    # @return [File] A file ready to be read.
    def fetch(&block)
      return cached_log if cached_log

      github_client = GithubClient.new(Configuration::User.instance.github_token)
      error = nil

      ::CLI::UI.spinner("Downloading CI logs from GitHub", auto_debrief: false) do
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

    # Store the log on the user's disk.
    #
    # @param logfile [Tempfile, IO] Depending on the size of the response. A quirk of URI.open.
    #
    # @return [void]
    def cache_log(logfile)
      FileUtils.mkdir_p(computed_file_path.dirname)

      if logfile.is_a?(Tempfile)
        FileUtils.cp(logfile, computed_file_path)
      else
        File.write(computed_file_path, logfile.read)
      end
    end

    # @return [String] A path where to store the logfile on the users' disk.
    #   The path is composed of the commit, the CI check name and the repository full name.
    #
    # @return [Pathname]
    #
    # @example Given a repository "rails/rails". A CI check called "Ruby 3.0". A commit "abcdef".
    #   puts computed_filed_path # ==> /var/tmpdir/T/.../rails/rails/log-abcdef-Ruby 3.0
    def computed_file_path
      normalized_run_name = @check_run["name"].tr("/", "_")

      log_folder.join("log-#{@commit[0..12]}-#{normalized_run_name}.log")
    end

    # @return [Pathname]
    def log_folder
      Pathname(Dir.tmpdir).join(@repository)
    end

    # @return [Pathname, false] Depending if the log has been downloaded before.
    def cached_log
      return false unless computed_file_path.exist?

      computed_file_path
    end
  end
end
