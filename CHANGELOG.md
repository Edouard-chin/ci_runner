# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [0.2.0] - 2022-8-22
### Added
- Added support for Circle CI.
- Added `ci_runner circle_ci_token` command. Storing a Circle CI token in your configuration is
  required for private builds.

### Changed
- CI Runner will now tell you if it fails to find test failures from the log output.
- CI Runner will only allow failed CI checks to be selected. Previously, users could select
  check that were cancelled, timed out etc...

### Fixed
- Fixed log detection for output that have ANSI colors (\e[31m Blabla)
