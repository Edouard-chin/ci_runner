## CI Runner

CI Runner is a Ruby library to **help rerun test failures from your CI on your local machine** without having to copy paste log output onto your terminal.
CI Runner can rerun failures for the _Minitest and RSpec_ test frameworks.

![demo](./demo.gif)

## :gear: Installation

```sh
gem install ci_runner
```

> **Note**
>
> CI Runner is meant to be installed as a standalone software and not added inside an application's Gemfile.

## Run CI Runner

### :unlock: Login

The first time you use CI Runner, you'll need to store a GitHub access_token. It's quick, I promise!

```sh
ci_runner help github_token
```

### :running_man: Run !

Once you have stored your token, you can run CI Runner main's command:
Both commands are identical, the second is just less typing 😄 .

```sh
ci_runner rerun
ci_runner
```

> **Note**
>
> You can also ask for help by typing `ci_runner help rerun`

## :question: How does it work

CI Runner fetch [GitHub Checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks) on your repository and download the associated logfile output on your laptop.
It then parses the log output to find relevant information and finally execute a command to **rerun exactly the same tests that failed
on your CI.**

#### :astonished: Test failures, Ruby version, specific Gemfile.

CI Runner aims to run tests on your local machine the same way as on CI. Therefore, CI runner **detects the Ruby version** used
on CI as well as **which set of dependencies (what Gemfile)**.

If a same Ruby version exists on your machine, CI runner will use that to rerun the test failures.

## :white_check_mark: Compatibility

CI Runner works with:

- :octocat: Repositories hosted on GitHub
- :octocat: GitHub CI
- :black_circle: Circle CI
- :test_tube: Minitest
- :test_tube: RSpec

If your project uses a different CI (Circle, Travis), please open an Issue to let me know you are interested 😸.

## :books: Wiki

The Wiki has more explanations on how CI Runner works and how you can configure it in case your projects uses
a non standard test output.
