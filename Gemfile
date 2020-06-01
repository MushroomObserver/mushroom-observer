# frozen_string_literal: true

source "https://rubygems.org"

# To bundle edge Rails instead: gem "rails", github: "rails/rails"
gem "rails", "~> 5.2.4"

# Use mysql2 as db connector
# See https://github.com/brianmario/mysql2
gem "mysql2"

# Use sqlite3 as the database for Active Record
# gem "sqlite3"

# Use SCSS for stylesheets
gem "sassc-rails"

# Use mini_racer as JavaScript runtime for ExecJS
# Note: ExecJS::RubyRacerRuntime is not supported.
#       Please replace therubyracer with mini_racer in your Gemfile or use Node.js as ExecJS runtime.
gem "mini_racer"

# Use CoffeeScript for .js.coffee assets and views
gem "coffee-rails"

# Enable ES6 modern JS parsing and transpiling to regular JS
gem "babel-source"
gem "babel-transpiler"
gem "sprockets", "~> 3.7.2"
gem "sprockets-es6"
# gem "sprockets-babel-miniracer", "~> 0.0.12"

# Use jquery as the JavaScript library
gem "jquery-rails"

# Use Uglifier as compressor for JavaScript assets
gem "uglifier"

# Turbolinks makes following links in your web application faster.
#    Read more: https://github.com/rails/turbolinks
#    Note: //= require turbolinks in application.js
# JS note: Refactor our js initializers. Turbolinks page-loads will fire
#    *their own* events, not the usual window and document load events
#
# Note: TL works better with StimulusJS: https://github.com/stimulusjs/stimulus
gem "turbolinks-source"
gem "turbolinks"

# Generates conditionally active menu links
gem 'active_link_to'

# Generates safe inline SVG from assets
gem 'inline_svg'

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

# email generation, parsing and sending
# version locked to prevent test failures caused by added "=0D" at the
# end of line in the body of plaintext emails.
# See https://www.pivotaltracker.com/story/show/172299270/comments/213574631
gem "mail", "= 2.7.0"

# for detecting file type of uploaded images
gem "mimemagic"

# Autoprefixer (Required dependency for Bootstrap 4)
# Parse CSS and add vendor prefixes to CSS rules
# using values from the Can I Use database
gem "autoprefixer-rails"


########## Mapping and Geocoding ###############################################

# Geocoder - Provides object geocoding (by street or IP address),
# reverse geocoding (coordinates to street address),
# distance queries for ActiveRecord and Mongoid, result caching
# https://github.com/alexreisner/geocoder
gem "geocoder"

# Geokit - Provides ActiveRecord distance-based finders.
# For example, find all the points in your database within a 50-mile radius.
# Optional IP-based location lookup utilizing hostip.info
# http://github.com/geokit/geokit
gem "geokit"


########## Presentation and Interaction ########################################

# Slick Slider for Image Carousel
# See https://github.com/kenwheeler/slick/
#     https://github.com/bodrovis/jquery-slick-rails
# gem "jquery-slick-rails"

# PopperJS tooltip positioner (Required dependency for Bootstrap 4)
gem "popper_js", "~> 1.16"

# Use Bootstrap for SCSS and JS
gem "bootstrap", "~> 4.4.1"

# Use Bootstrap Lightbox for lightbox
gem "lightbox-bootstrap-rails", "~> 5.1", ">= 5.1.0.1"


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

group :development do
  # Use Rails DB to browse database at http://localhost:3000/rails/db/
  gem "rails_db"
end

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
