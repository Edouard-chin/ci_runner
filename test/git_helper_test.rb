# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"

module CIRunner
  class GitHelperTest < Minitest::Test
    def setup
      super

      @dir = Dir.mktmpdir
      @previous_dir = Dir.pwd

      Dir.chdir(@dir)
      File.write("some_file", "abc")

      run_git_command("git config --global user.email 'you@example.com'")
      run_git_command("git config --global user.name 'Your Name'")
      run_git_command("git init")
      run_git_command("git add -A")
      run_git_command("git commit -m 'WIP'")
    end

    def teardown
      FileUtils.rm_rf(@dir) if @dir
      Dir.chdir(@previous_dir)

      super
    end

    def test_head_commit
      head_commit = GitHelper.head_commit

      assert_equal(40, head_commit.length)
    end

    def test_repository_from_remote_git_origin
      _, status = Open3.capture2("git remote add origin git@github.com:Edouard-chin/ci_runner.git")
      raise("Couldn't add a remote to the test git repository") unless status.success?

      repository = GitHelper.repository_from_remote

      assert_equal("Edouard-chin/ci_runner", repository)
    end

    def test_repository_from_remote_https_origin
      _, status = Open3.capture2("git remote add origin https://github.com/Edouard-chin/ci_runner.git")
      raise("Couldn't add a remote to the test git repository") unless status.success?

      repository = GitHelper.repository_from_remote

      assert_equal("Edouard-chin/ci_runner", repository)
    end

    def test_repository_from_remote_git_remote
      _, status = Open3.capture2("git remote add remote git@github.com:Edouard-chin/ci_runner.git")
      raise("Couldn't add a remote to the test git repository") unless status.success?

      repository = GitHelper.repository_from_remote

      assert_equal("Edouard-chin/ci_runner", repository)
    end

    def test_repository_from_remote_https_remote
      _, status = Open3.capture2("git remote add remote https://github.com/Edouard-chin/ci_runner.git")
      raise("Couldn't add a remote to the test git repository") unless status.success?

      repository = GitHelper.repository_from_remote

      assert_equal("Edouard-chin/ci_runner", repository)
    end

    def test_repository_from_remote_remote_has_precedence
      _, status = Open3.capture2("git remote add origin https://github.com/Edouard-chin/ci_runner.git")
      raise("Couldn't add a remote to the test git repository") unless status.success?

      _, status = Open3.capture2("git remote add remote https://github.com/some_name/ci_runner.git")
      raise("Couldn't add a remote to the test git repository") unless status.success?

      repository = GitHelper.repository_from_remote

      assert_equal("some_name/ci_runner", repository)
    end

    def test_repository_from_remote_origin_has_precedence
      _, status = Open3.capture2("git remote add some_remote https://github.com/Edouard-chin/ci_runner.git")
      raise("Couldn't add a remote to the test git repository") unless status.success?

      _, status = Open3.capture2("git remote add remote https://github.com/some_name/ci_runner.git")
      raise("Couldn't add a remote to the test git repository") unless status.success?

      repository = GitHelper.repository_from_remote

      assert_equal("some_name/ci_runner", repository)
    end

    def test_repository_from_remote_with_different_name
      _, status = Open3.capture2("git remote add some_remote https://github.com/Edouard-chin/ci_runner.git")
      raise("Couldn't add a remote to the test git repository") unless status.success?

      repository = GitHelper.repository_from_remote

      assert_equal("Edouard-chin/ci_runner", repository)
    end

    def test_repository_from_remote_raise_when_repository_cant_be_determined
      _, status = Open3.capture2("git remote add origin https://scv.com/Edouard-chin/ci_runner.git")
      raise("Couldn't add a remote to the test git repository") unless status.success?

      error = assert_raises(Error) do
        GitHelper.repository_from_remote
      end

      expected = <<~EOM
        Couldn't determine the repository name based on the git remote.

        Please pass the `--repository` flag (ci_runner --repository <owner/repository_name>)
      EOM
      assert_equal(expected, error.message)
    end

    private

    def run_git_command(command)
      _, _, status = Open3.capture3(command)

      raise("Git command #{command} failed") unless status.success?
    end
  end
end
