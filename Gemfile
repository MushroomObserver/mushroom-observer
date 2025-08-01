# frozen_string_literal: true

ruby(File.read(".ruby-version").strip)

# As of Ruby 3.0, the SortedSet class has been extracted from the set library.
# You must use the sorted_set gem or other alternatives
gem("sorted_set")

source("https://rubygems.org")

# To bundle edge Rails instead: gem "rails", github: "rails/rails"
# gem("rails", "~> 7.2.2.1")

# To skip loading parts of Rails, bundle the constituent gems separately.
# NOTE: Remember to require the classes also, in config/application.rb
# NOTE: Be sure no other gems list `rails` as a dependency in Gemfile.lock,
#       or else all of Rails will load anyway.
#
# Convenience group for updating rails constituents with one command
# Usage: bundle update --group==rails
group :rails do
  gem("actioncable", "~> 7.2.2.1")
  # gem("actionmailbox", "~> 7.2.2.1")
  gem("actionmailer", "~> 7.2.2.1")
  gem("actionpack", "~> 7.2.2.1")
  # gem("actiontext", "~> 7.2.2.1")
  gem("actionview", "~> 7.2.2.1")
  gem("activejob", "~> 7.2.2.1")
  gem("activemodel", "~> 7.2.2.1")
  gem("activerecord", "~> 7.2.2.1")
  # gem("activestorage", "~> 7.2.2.1")
  gem("activesupport", "~> 7.2.2.1")
  gem("bundler")
  gem("railties", "~> 7.2.2.1")
end

# Use trilogy as db connector
# See https://github.com/trilogy-libraries/trilogy/tree/main/contrib/ruby
gem("trilogy")

# solid_cache for cache store db
gem("solid_cache")
# add locale to cache key
gem("cache_with_locale")
# solid_queue for jobs
gem("solid_queue")
# https://github.com/rails/mission_control-jobs
# Rails-based frontend to Active Job adapters for monitoring jobs
gem("mission_control-jobs")
# solid_cable for ActionCable without Redis
gem("solid_cable")

# sprockets for asset compilation and versioning
gem("sprockets-rails")
# Fix a version problem betw stimulus and sprockets. (not sprockets-rails)
# Delete this dependency declaration if the issue gets resolved:
# https://github.com/hotwired/stimulus-rails/issues/108
gem("sprockets", "~>4.2.1")
# Compile SCSS for stylesheets
gem("dartsass-sprockets")
# Use bootstrap style generator
gem("bootstrap-sass")
# Use Terser as compressor for JavaScript assets
gem("terser")

# importmap for js module handling
gem("importmap-rails")
# stimulus for simpler, more maintainable js
gem("stimulus-rails")
# requestjs for simpler js requests from stimulus
gem("requestjs-rails")
# turbo for partial page updates
gem("turbo-rails")
# minimal two way bridge between the V8 JavaScript engine and Ruby
# Locked here because "0.19.0" will not compile for nimmolo
gem("mini_racer", "~> 0.18.1")

# Add Arel helpers for more concise query syntax in Arel
# https://github.com/camertron/arel-helpers
gem("arel-helpers")
# https://github.com/Faveod/arel-extensions
gem("arel_extensions")

# Provide abstract base class for classes that depend upon method_missing
gem("blankslate")

# Simple version models and tables for classes
# Use our own fork, which stores enum attrs as integers in the db
gem("mo_acts_as_versioned", ">= 0.6.6",
    git: "https://github.com/MushroomObserver/acts_as_versioned")

# Use ActiveModel has_secure_password
gem("bcrypt")

# Use Capistrano for deployment
# gem("capistrano", group: :development)

# Use i18n for internationalization
gem("i18n")

# Detect which browser is used
gem("browser")

# Enable Textile markup language. See https://github.com/jgarber/redcloth,
# https://textile-lang.com/doc/insertions-and-deletions
gem("RedCloth")
# Create Rich Text Format documents
gem("rtf")

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem("jbuilder")
# Enable remote procedure calls over HTTP (used in MO API)
gem("xmlrpc")

# Get image sizes from a file
gem("fastimage")
# for detecting file type of uploaded images
gem("mimemagic")

# Gems used for iNat import
gem("oauth2")
gem("rest-client")

# Read original images from google cloud storage
gem("google-cloud-storage")

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
gem("rubyzip", "~> 2.4.1")

# QR code generator
gem("rqrcode")

# PDF generation support.  prawn-svg is supposed to come before prawn.
gem("prawn-svg")

# And now prawn in a separate 'section' to make rubocop happy.
gem("prawn")
gem("prawn-manual_builder")

# csv generation support
gem("csv")

# calculate the Haversine distance between two points given their lat/lng
# https://github.com/kristianmandrup/haversine
gem("haversine")

# Use puma as the app server, also available for system tests
# To use Webrick locally, run `bundle config set --local without 'production'`
# https://stackoverflow.com/a/23125762/3357635
gem("puma")

########## Development, Testing, and Analysis ##################################
group :test, :development do
  # https://github.com/ruby/debug
  gem("debug")

  # Use built-in Ruby coverage to generate html coverage file
  gem("simplecov", require: false)
  # generate lcov file to send to Coveralls by Github Actions
  gem("simplecov-lcov", require: false)

  # Brakeman static analysis security scanner
  # See http://brakemanscanner.org/
  gem("brakeman", require: false)

  # Use rubocop and extensions for code quality control
  # https://docs.rubocop.org/rubocop/extensions.html#cop-extensions
  gem("rubocop", require: false)
  gem("rubocop-performance")
  gem("rubocop-rails")
  gem("rubocop-thread_safety", require: false)
end

group :test do
  # Use capybara to simulate user-browser interaction
  gem("capybara")
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
  # gem("newrelic_rpm")
end
