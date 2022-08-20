# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "fileutils"

module CIRunner
  # A PORO to help download and cache a GitHub CI log.
  #
  # @example Using the service
  #   log_dl = LogDownloader.new(
  #     CICheck::GitHub.new(
  #       "catanacorp/catana",
  #       "commit_sha",
  #       "Tests Ruby 2.7",
  #       "failed",
  #       12345,
  #     )
  #   )
  #   log_file = log_dl.fetch
  #   puts log_file # => File
  class LogDownloader
    # @param check_run [Check::Base] A Base::Check subclass for which we want to download the log.
    def initialize(check_run)
      @check_run = check_run
    end

    # Ask the +@check_run+ to download the log from its CI or retrieve it from disk in case we previously downloaded it.
    #
    # @param block [Proc, Lambda] A proc that gets called if fetching the logs from GitHub fails. Allows the CLI to
    #   prematurely exit while cleaning up the CLI::UI frame.
    #
    # @return [Pathname] The path to the log file.
    def fetch(&block)
      return cached_log if cached_log

      error = nil

      ::CLI::UI.spinner("Downloading CI logs from #{@check_run.provider}", auto_debrief: false) do
        cache_log(@check_run.download_log)
      rescue Client::Error, Error => e
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
      normalized_run_name = @check_run.name.tr("/", "_")

      log_folder.join("log-#{@check_run.commit[0..12]}-#{normalized_run_name}.log")
    end

    # @return [Pathname]
    def log_folder
      Pathname(Dir.tmpdir).join(@check_run.repository)
    end

    # @return [Pathname, false] Depending if the log has been downloaded before.
    def cached_log
      return false unless computed_file_path.exist?

      computed_file_path
    end
  end
end
