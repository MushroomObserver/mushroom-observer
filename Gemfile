# frozen_string_literal: true

ruby(File.read(".ruby-version").strip)

# In Ruby, 3.0, the SortedSet class has been extracted from the set library.
# You must use the sorted_set gem or other alternatives
gem("sorted_set")

source("https://rubygems.org")

# To bundle edge Rails instead: gem "rails", github: "rails/rails"
# gem("rails", "~> 7.0")

# To skip loading parts of Rails, bundle the constituent gems separately.
# NOTE: Remember to require the classes also, in config/application.rb
# NOTE: Be sure no other gems list `rails` as a dependency in Gemfile.lock,
#       or else all of Rails will load anyway.
#
# Convenience group for updating rails constituents with one command
# Usage: bundle update --group==rails
group :rails do
  gem("actioncable", "~> 7.0")
  # gem("actionmailbox", "~> 7.0")
  gem("actionmailer", "~> 7.0")
  gem("actionpack", "~> 7.0")
  # gem("actiontext", "~> 7.0")
  gem("actionview", "~> 7.0")
  gem("activejob", "~> 7.0")
  gem("activemodel", "~> 7.0")
  gem("activerecord", "~> 7.0")
  # gem("activestorage", "~> 7.0")
  gem("activesupport", "~> 7.0")
  gem("bundler")
  gem("railties", "~> 7.0")
end

# gem irb now depends on psych, but version 5 will not bundle currently
gem("psych", "~> 4")
# importmap for js module handling
gem("importmap-rails")
# sprockets for asset compilation and versioning
gem("sprockets-rails")
# stimulus for simpler, more maintainable js
gem("stimulus-rails")
# requestjs for simpler js requests from stimulus
gem("requestjs-rails")
# turbo for partial page updates
gem("turbo-rails")
# redis for combining actioncable broadcasts with turbo_stream
# gem("redis", "~> 4.0")
# Compile SCSS for stylesheets
gem("sassc-rails")

# Fix a version problem betw stimulus and sprockets. (not sprockets-rails)
# Delete this dependency declaration if the issue gets resolved:
# https://github.com/hotwired/stimulus-rails/issues/108
gem("sprockets", "~>4.2.1")

# Security fix updates via Dependabot
# CVE-2021-41817 regex denial of service vulnerability
gem("date", ">= 3.2.1")
# CVE-2022-23476
gem("nokogiri", ">= 1.13.10")
# CVE-2022-23515
gem("loofah", ">= 2.19.1")
# CVE-2022-23518
gem("rails-html-sanitizer", ">= 1.4.4")

# Use mysql2 as db connector
# See https://github.com/brianmario/mysql2
gem("mysql2")

# Use sqlite3 as the database for Active Record
# gem("sqlite3")

# Add Arel helpers for more concise query syntax in Arel
# https://github.com/camertron/arel-helpers
gem("arel-helpers")
# https://github.com/Faveod/arel-extensions
gem("arel_extensions")

# Use bootstrap style generator
gem("bootstrap-sass")

# Use mini_racer as a substitute for therubyracer
# If having trouble installing this gem in Vagrant:
# gem update --system
# bundler update
gem("mini_racer")

# Use Uglifier as compressor for JavaScript assets
gem("uglifier")

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem("jbuilder")

# Use ActiveModel has_secure_password
gem("bcrypt", "~> 3.1.7")

# Use unicorn as the app server
gem("unicorn")

# Use Capistrano for deployment
# gem("capistrano", group: :development)

# Use i18n for internationalization
gem("i18n")

# Enable Textile markup language. See https://github.com/jgarber/redcloth,
# https://textile-lang.com/doc/insertions-and-deletions
gem("RedCloth")

# Provide abstract base class for classes that depend upon method_missing
gem("blankslate")

# Detect which browser is used
gem("browser")

# Create Rich Text Format documents
gem("rtf")

# Enable remote procedure calls over HTTP (used in MO API)
gem("xmlrpc")

# Get image sizes from a file
gem("fastimage")

# Simple versioning
# Use our own fork, which stores enum attrs as integers in the db
gem("mo_acts_as_versioned", ">= 0.6.6",
    git: "https://github.com/MushroomObserver/acts_as_versioned/")

# email generation, parsing and sending
gem("mail")
# Action Mailbox depends on net/smtp, but not included with Ruby 3.1
# temporarily add until the mail gem includes it as a dependancy.
gem("net-smtp", require: false)

# These seem to be required by unicorn -> zeitwerk
gem("net-imap")
gem("net-pop")

# for detecting file type of uploaded images
gem("mimemagic")

# for creating zip files
# RubyZip 3.0 is coming!
# **********************

# The public API of some Rubyzip classes has been modernized to use named
# parameters for optional arguments. Please check your usage of the
# following classes:
#   * `Zip::File`
#   * `Zip::Entry`
#   * `Zip::InputStream`
#   * `Zip::OutputStream`

# Please ensure that your Gemfiles and .gemspecs are suitably restrictive
# to avoid an unexpected breakage when 3.0 is released (e.g. ~> 2.3.0).
# See https://github.com/rubyzip/rubyzip for details. The Changelog also
# lists other enhancements and bugfixes that have been implemented since
# version 2.3.0.
gem("rubyzip", "~> 2.3.0")

########## Development, Testing, and Analysis ##################################
group :test, :development do
  # https://github.com/ruby/debug
  gem("debug", ">= 1.0.0")

  # Use built-in Ruby coverage to generate html coverage file
  gem("simplecov", require: false)
  # generate lcov file to send to Coveralls by Github Actions
  gem("simplecov-lcov", require: false)

  # Brakeman static analysis security scanner
  # See http://brakemanscanner.org/
  gem("brakeman", require: false)

  # Use rubocop and extensions for code quality control
  # https://docs.rubocop.org/rubocop/extensions.html#cop-extensions
  # NOTE: If updating RuboCop:
  #  - Update any extension used here
  #  - Use highest available .codeclimate.yml rubocop channel
  #    https://github.com/codeclimate/codeclimate-rubocop/branches/all?utf8=%E2%9C%93&query=channel%2Frubocop
  gem("rubocop", require: false)
  gem("rubocop-performance")
  gem("rubocop-rails")
end

group :test do
  # Use capybara to simulate user-browser interaction
  gem("capybara", "~> 3.37", ">= 3.37.1")

  # Use cuprite to run the browser in Capybara tests
  gem("cuprite")

  # Selenium recommends Database Cleaner for cleaning db between tests.
  # Maybe needed after JS db transactions, because they run in a separate thread
  # from the test server. https://github.com/DatabaseCleaner/database_cleaner
  gem("database_cleaner-active_record")

  # allows test results to be reported back to test runner IDE's
  gem("minitest")
  gem("minitest-reporters")

  # restore `assigns` and `assert_template` to tests
  gem("rails-controller-testing")

  # Performance tests for Rails >= 4.0
  # See https://github.com/rails/rails-perftest
  # gem("rails-perftest", group: :test)

  # Stub and set expectations on HTTP requests in test mode
  # Allow selective disabling of internet
  gem("webmock")

  # Check for N+1 queries and unused eager loading.
  gem("bullet")
end

group :development do
  # Calling `console` creates irb session in the browser (instead of terminal)
  gem("web-console")

  # Use Rails DB to browse database at http://localhost:3000/rails/db/
  # gem("rails_db", "~> 2.5.0", path: "../local_gems/rails_db")
end

group :production do
  # New Relic for application and other monitoring
  # https://newrelic.com/
  gem("newrelic_rpm")
end
