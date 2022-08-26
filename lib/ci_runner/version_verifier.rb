# frozen_string_literal: true

require "fileutils"

module CIRunner
  # Class used to check if a newer version of CI Runner has been released.
  # This is used to inform the user to update its gem.
  #
  # The check only runs every week.
  class VersionVerifier
    SEVEN_DAYS = 86_400 * 7

    # Check if the user is running the latest version of CI Runner.
    #
    # @return [Boolean]
    def new_ci_runner_version?
      return false unless check?

      fetch_upstream_version
      FileUtils.touch(last_checked)

      upstream_version > Gem::Version.new(VERSION)
    end

    # Makes a request to GitHub to get the latest release on the Edouard-chin/ci_runner repository
    #
    # @return [Gem::Version] An instance of Gem::Version
    def upstream_version
      @upstream_version ||= begin
        release = Client::Github.new(Configuration::User.instance.github_token).latest_release("Edouard-chin/ci_runner")

        Gem::Version.new(release["tag_name"].sub(/\Av/, ""))
      end
    end
    alias_method :fetch_upstream_version, :upstream_version

    # Path of a file used to store when we last checked for a release.
    #
    # @return [Pathname]
    def last_checked
      Configuration::User.instance.config_directory.join("last-checked")
    end

    private

    # @return [Boolean] Whether we checked for a release in the 7 days.
    def check?
      Time.now > (File.stat(last_checked).mtime + SEVEN_DAYS)
    rescue Errno::ENOENT
      true
    end
  end
end
