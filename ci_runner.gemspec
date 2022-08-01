# frozen_string_literal: true

require_relative "lib/ci_runner/version"

Gem::Specification.new do |spec|
  spec.name = "ci_runner"
  spec.version = CIRunner::VERSION
  spec.authors = ["Edouard Chin"]
  spec.email = ["chin.edouard@gmail.com"]

  spec.summary = "Re-run failing tests from CI on your local machine without copy/pasting anything."
  spec.description = <<~EOM
    Tired of copying the test suites names from a failed CI?

    This gem will automate this tedious workflow. CI-runner will run all the failing tests from CI on your machine.
  EOM
  spec.homepage = "https://github.com/Edouard-chin/ci_runner"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Edouard-chin/ci_runner"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = ["ci_runner"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor"
  spec.add_dependency "cli-ui"
  spec.add_dependency "rake"

  spec.add_development_dependency("webmock")
  spec.add_development_dependency("rspec")

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
