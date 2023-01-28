# Mushroom Observer

<!-- Most links are defined here for DRYness and consistency -->
[Brakeman]: https://brakemanscanner.org/
[Codeclimate]: https://codeclimate.com
[codeclimate_maintainability_badge]: https://codeclimate.com/github/MushroomObserver/mushroom-observer.png
[codeclimate_status_overview]: https://codeclimate.com/github/MushroomObserver/mushroom-observer
[Coveralls]: https://coveralls.io/
[coveralls_badge]: https://coveralls.io/repos/MushroomObserver/mushroom-observer/badge.png?branch=main
[coveralls_build]: https://coveralls.io/r/MushroomObserver/mushroom-observer?branch=main
[Gemfile]: [/Gemfile]
[git]: https://git-scm.com/
[Github Actions]: https://docs.github.com/en/actions
[github_actions_badge]: https://github.com/MushroomObserver/mushroom-observer/workflows/Continuous%20Integration/badge.svg
[github_actions_workflow_runs]: https://github.com/MushroomObserver/mushroom-observer/actions
[License]: /LICENSE
[minitest]: http://docs.seattlerb.org/minitest/
[RuboCop]: https://rubocop.org/

<!-- Badges -->
[![Actions Status][github_actions_badge]][github_actions_workflow_runs]
[![CodePolice][codeclimate_maintainability_badge]][codeclimate_status_overview]
[![Coverage Status][coveralls_badge]][coveralls_build]

Last Revised: 2023-01-08

This README is an overview of

- the tools used by Mushroom Observer (MO) and
- the other READMEs in this repository.

See
<https://mushroomobserver.org/info/intro>
for an introduction to the website itself.

-----

## TOOLS

### [git][git]

MO uses [git][git] for version control and management of MO code.
The source code is hosted on github. The URL for the MO source repository is
<https://github.com/MushroomObserver/mushroom-observer>.

### [Github Actions][Github Actions]

We use [Github Actions][Github Actions]
to implement Continuous Integration (CI).
Pushing a commit to GitHub triggers a workflow run that includes:

- testing with [minitest][minitest],
- submitting the results to [Coveralls][Coveralls] to get a coverage report,
- running [Codeclimate][CodeClimate] to get a quality control report.

### [minitest][minitest]

Our test suite uses [minitest][minitest] and extensions.
See our [Gemfile][Gemfile] for more details.
The test suite is run as part of our CI, and also can be run locally.

### [Coveralls][Coveralls]

We use [Coveralls][Coveralls] to obtain a
[report about test coverage][coveralls_build].
Coveralls is run as part of our CI, and also can be run locally.
Its reports include total coverage and coverage for each line of code.
The reports highlight newly uncovered lines
so that we can maintain a high degree of coverage.

### [Codeclimate][CodeClimate]

We use [Codeclimate][CodeClimate]
and plugins, like [RuboCop][RuboCop] and [Brakeman][Brakeman],
to help maintain and improve code quality, including a consistent style.
See our [Codeclimate configuration file](/.codeclimate.yml) for more details.

### [RuboCop][RuboCop]

We use [RuboCop][RuboCop] and extensions to help with
code quality and consistentcy of style.
See our [RuboCop configuration file](/.rubocop.yml) for more details.
[RuboCop][RuboCop] is run as part of our CI, and also can be run locally.
(We are a long way from where we want to be.
We have hundreds of offenses to fix.
See our [Ruboco Todo file](.rubocop_todo.yml).)

### [Brakeman][Brakeman]

We use [Brakeman][Brakeman] to highight some security issues.

-----

## DEVELOPMENT

To get started developing we recommend that you head over to
<https://github.com/MushroomObserver/developer-startup> which provides
instructions for getting a virtual machine development environment set up on
Mac, Linux and Windows machines.

-----

## Other READMEs

The following files should provide useful information for working with the
Mushroom Observer code base. These files are quite out-of-date,
so be sure to take them with a grain of salt.

[README_CODE](README_CODE):
Provides a snapshot of the major components of Mushroom Observer.

[README_DEVELOPMENT_INSTALL](README_DEVELOPMENT_INSTALL):
If for some reason you want to install our code locally,
this file describes the steps used by one developer.
You are encouraged to update this document with your own experience.
Also see [MACOSX_NOTES](MACOSX_NOTES) for notes about setting up a
local Apple M1 working under the Monterey (12.4) version of MacOS.
>Rather than running our code locally on your hardware,
we recommend using the process outlined in
<https://github.com/MushroomObserver/developer-startup>
to create a development environment on a virtual machine.

[README_PRODUCTION_INSTALL](README_PRODUCTION_INSTALL):
Describes the steps needed to setup our production environment.

[README_STANDARDS](README_STANDARDS):
The closest we have to coding standards.  Currently this is *very* brief.

[README_TRANSLATIONS](README_TRANSLATIONS):
Details needed for translators to provide support in for the site
in a new language.

-----

Copyright (c) © 2006-2023 Mushroom Observer, Inc.
See [License][License] for further details.
