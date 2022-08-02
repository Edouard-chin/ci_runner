# frozen_string_literal: true

require_relative "lib/ci_runner/version"

Gem::Specification.new do |spec|
  spec.name = "ci_runner"
  spec.version = CIRunner::VERSION
  spec.authors = ["Edouard Chin"]
  spec.email = ["chin.edouard@gmail.com"]

  spec.summary = "Re-run failing tests from CI on your local machine without copy/pasting."
  spec.description = <<~EOM
    Tired of copying the test suites names from a failed CI?

    This gem will automate this tedious workflow. CI Runner will download the log from your CI
    provider, parse it, detect failures and rerun exactly the same failing tests on your machine.

    CI Runner can also detect the Ruby version used on your CI as well as which Gemfile and reuse
    those when starting the run locally.
  EOM
  spec.homepage = "https://github.com/Edouard-chin/ci_runner"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Edouard-chin/ci_runner"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["{lib,exe}/**/*", "ci_runner.gemspec"].select { |f| File.file?(f) }

  spec.bindir = "exe"
  spec.executables = ["ci_runner"]
  spec.require_paths = ["lib"]

  spec.add_dependency("cli-ui", "~> 1.5")
  spec.add_dependency("rake", "~> 13.0")
  spec.add_dependency("thor", "~> 1.2")

  spec.add_development_dependency("rspec", "~> 3.11")
  spec.add_development_dependency("rubocop-shopify", "~> 2.8")
  spec.add_development_dependency("webmock", "~> 3.14")
end
