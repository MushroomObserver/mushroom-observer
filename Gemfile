source "https://rubygems.org"

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
gem "sass-rails"

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
gem "unicorn"

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

# Use byebug as debugging gem
gem "byebug", group: [:development, :test]

# Automatically track code test coverage
gem "coveralls", require: false

# Use rubocop for code style quality control
gem "rubocop", require: false

# Brakeman static analysis security scanner
# See http://brakemanscanner.org/
# We don't need the gem because CodeClimate CI includes a Brakeman engine.
# gem "brakeman", require: false

# Amazon S3 SDK, for access to images on dreamhost S3
# limited to v2 to avoid installing a bunch of gems
gem "aws-sdk", "~> 2"

# Slick Slider for Image Carousel
# See https://github.com/kenwheeler/slick/
#     https://github.com/bodrovis/jquery-slick-rails
gem "jquery-slick-rails"

# Calling `console` creates irb session in the browser (instead of the terminal)
gem "web-console", group: :development

gem "mail", "= 2.7.0"

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
