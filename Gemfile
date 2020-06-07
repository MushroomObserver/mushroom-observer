# frozen_string_literal: true

source "https://rubygems.org"

gem "sprockets"

# To bundle edge Rails instead: gem "rails", github: "rails/rails"
gem "rails", "~> 5.2.2"

# Use mysql2 as db connector
# See https://github.com/brianmario/mysql2
gem "mysql2"

# Use sqlite3 as the database for Active Record
# gem "sqlite3"

# Use bootstrap style generator
gem "bootstrap-sass"

# Use SCSS for stylesheets
gem "sassc-rails"

# Use jquery as the JavaScript library
gem "jquery-rails"

# Use thebuyracer as JavaScript runtime for ExecJS
# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem "therubyracer", platforms: :ruby

# Use CoffeeScript for .js.coffee assets and views
gem "coffee-rails"

# Use Uglifier as compressor for JavaScript assets
gem "uglifier"

# Turbolinks makes following links in your web application faster.
# Read more: https://github.com/rails/turbolinks
# gem "turbolinks"

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem "jbuilder"

# Use ActiveModel has_secure_password
# gem "bcrypt", "~> 3.1.7"

# Use unicorn as the app server
gem "unicorn", "5.4.1"

# Use Capistrano for deployment
# gem "capistrano", group: :development

# Use i18n for internationalization
gem "i18n"

# Enable Textile markup language. See http://redcloth.org/
gem "RedCloth"

# Provide abstract base class for classes that depend upon method_missing
gem "blankslate"

# Detect which browser is used
gem "browser"

# Create Rich Text Format documents
gem "rtf"

# Enable remote procedure calls over HTTP (used in MO API)
gem "xmlrpc"

# Simple versioning
gem "cure_acts_as_versioned"

# In Rails 4.0, use simple_enum to replace enum_column3
# In Rails >= 4.1, use Rails built-in enums instead (available only in >= 4.1)
gem "simple_enum"

# Amazon S3 SDK, for access to images on dreamhost S3
gem "aws-sdk-s3"

# Slick Slider for Image Carousel
# See https://github.com/kenwheeler/slick/
#     https://github.com/bodrovis/jquery-slick-rails
gem "jquery-slick-rails"

# email generation, parsing and sending
# version locked to prevent test failures caused by added "=0D" at the
# end of line in the body of plaintext emails.
# See https://www.pivotaltracker.com/story/show/172299270/comments/213574631
gem "mail", "= 2.7.0"

# for detecting file type of uploaded images
gem "mimemagic"

########## Development, Testing, and Analysis ##################################

# Use byebug as debugging gem
gem "byebug", group: [:development, :test]

# Calling `console` creates irb session in the browser (instead of the terminal)
gem "web-console", group: :development

# Automatically track code test coverage
gem "coveralls", require: false

# Brakeman static analysis security scanner
# See http://brakemanscanner.org/
gem "brakeman", require: false

# Use rubocop and associated gems for code quality control
# WARNING: Whenever updating RuboCop, also:
#   - Update .codeclimate.yml's RuboCop channel whenever we update RuboCop.
#       docs.codeclimate.com/docs/rubocop#section-using-rubocop-s-newer-versions
#   - Regenerate .rubocop_todo.yml
#     https://docs.rubocop.org/en/stable/configuration,
#       Automatically Generated Configuration
# Temporarily lock RuboCop version while we are working our way through
# auto-correctable offenses
gem "rubocop", "= 0.83", require: false
gem "rubocop-performance"
gem "rubocop-rails"

# use mry to support safe updating of .rubocop.yml
gem "mry", require: false

group :test do
  # Use capybara to simulate user-browser interaction
  gem "capybara"

  # allows test results to be reported back to test runner IDE's
  gem "minitest"
  gem "minitest-reporters"

  # Mocking and stubbing in Ruby
  gem "mocha"

  # restore `assigns` and `assert_template` to tests
  gem "rails-controller-testing"

  # Performance tests for Rails >= 4.0
  # See https://github.com/rails/rails-perftest
  # gem "rails-perftest", group: :test

  # Stub and set expectations on HTTP requests in test mode
  # Allow selective disabling of internet
  gem "webmock"
end
