# frozen_string_literal: true

source("https://rubygems.org")

gem("sprockets")

# To bundle edge Rails instead: gem "rails", github: "rails/rails"
gem("rails", "~> 5.2.2")

# Use mysql2 as db connector
# See https://github.com/brianmario/mysql2
gem("mysql2")

# Use sqlite3 as the database for Active Record
# gem "sqlite3"

# Use bootstrap style generator
gem("bootstrap-sass")

# Use SCSS for stylesheets
gem("sassc-rails")

# Use jquery as the JavaScript library
gem("jquery-rails")

# Use therubyracer as JavaScript runtime for ExecJS
# See https://github.com/sstephenson/execjs#readme for more supported runtimes
# gem("therubyracer", platforms: :ruby)

# Use mini_racer as a substitute for therubyracer
gem("mini_racer")

# Use CoffeeScript for .js.coffee assets and views
gem("coffee-rails")

# Use Uglifier as compressor for JavaScript assets
gem("uglifier")

# Turbolinks makes following links in your web application faster.
# Read more: https://github.com/rails/turbolinks
# gem "turbolinks"

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem("jbuilder")

# Use ActiveModel has_secure_password
# gem "bcrypt", "~> 3.1.7"

# Use unicorn as the app server
gem("unicorn", "5.4.1")

# Use Capistrano for deployment
# gem "capistrano", group: :development

# Use i18n for internationalization
gem("i18n")

# Enable Textile markup language. See http://redcloth.org/
gem("RedCloth")

# Provide abstract base class for classes that depend upon method_missing
gem("blankslate")

# Detect which browser is used
gem("browser")

# Create Rich Text Format documents
gem("rtf")

# Enable remote procedure calls over HTTP (used in MO API)
gem("xmlrpc")

# Simple versioning
# Use our own fork, which stores enum attrs as integers in the db
gem("cure_acts_as_versioned",
    git: "https://github.com/MushroomObserver/acts_as_versioned/")

# In Rails 4.0, use simple_enum to replace enum_column3
# In the future, replace simple_enum with Rails native enums
# https://www.pivotaltracker.com/story/show/90595194
gem("simple_enum")

# Amazon S3 SDK, for access to images on dreamhost S3
gem("aws-sdk-s3")

# Slick Slider for Image Carousel
# See https://github.com/kenwheeler/slick/
#     https://github.com/bodrovis/jquery-slick-rails
gem("jquery-slick-rails")

# email generation, parsing and sending
# version locked to prevent test failures caused by added "=0D" at the
# end of line in the body of plaintext emails.
# See https://www.pivotaltracker.com/story/show/172299270/comments/213574631
gem("mail", "= 2.7.0")

# for detecting file type of uploaded images
gem("mimemagic")

# for creating zip files
gem("rubyzip")

########## Development, Testing, and Analysis ##################################

# Automatically track code test coverage
# Use coveralls_reborn gem instead of coveralls gem
# With `coveralls` Travis CI runnning with Ubuntu focal gets an SSLError
# when Travis submits the coverage report to Coveralls
gem("coveralls_reborn", "~> 0.20.0", require: false)

# Brakeman static analysis security scanner
# See http://brakemanscanner.org/
gem("brakeman", require: false)

# Use rubocop and associated gems for code quality control
#
# WARNING:
# When upgrading RuboCop, please use the procedure specified in .rubocop.yml
#
# Temporarily lock RuboCop version while we are working our way through
# auto-correctable offenses
gem("rubocop", "= 0.89", require: false)
gem("rubocop-performance")
gem("rubocop-rails")

# use mry to support safe updating of .rubocop.yml
gem("mry", require: false)

# GraphQL API gems
gem("graphql")

# Rubocop extension for enforcing graphql-ruby best practices.
# You need to tell RuboCop to load the GraphQL extension. rubocop.yml
# require:
#  - rubocop-other-extension
#  - rubocop-graphql
# http://github.com/DmitryTsepelev/rubocop-graphql
gem("rubocop-graphql", require: false)

# Search Object (and GraphQL extension) for filtering queries
# https://github.com/RStankov/SearchObjectGraphQL
gem("search_object")
gem("search_object_graphql")

# A sweet, extended DSL written on top of the graphql-ruby gem. Outdated! :(
# Easily write object and input types that are backed by ActiveRecord models
# Easily write resolvers and mutators to encapsulate query and mutation logic
# https://github.com/keepworks/graphql-sugar
# https://github.com/keepworks/graphql-sugar/issues/7
gem("graphql-sugar", path: "../graphql-sugar")

# Dataloading gems
# Note that dataloader comes shipped with graphql gem as of 1.12
# It's also experimental. Below are some alternatives
# https://evilmartians.com/chronicles/how-to-graphql-with-ruby-rails-active-record-and-no-n-plus-one

# Provides an executor for the graphql gem which allows queries to be batched.
# https://github.com/Shopify/graphql-batch
gem("graphql-batch")

# Brings association lazy load functionality to your Rails applications
# https://github.com/DmitryTsepelev/ar_lazy_preload
gem("ar_lazy_preload")

# (Similar to graphql-batch and maybe ar_lazy_preload)
# Provides a generic lazy batching mechanism to avoid N+1 DB queries,
# HTTP queries, etc. Maybe better than the above?
# https://github.com/exAspArk/batch-loader
# https://github.com/exAspArk/batch-loader#alternatives
# gem("batch-loader")

# (Similar to ar_lazy_preload)
# Old add-on to graphql-ruby that allows your field resolvers to minimize N+1
# SELECTS issued by ActiveRecord. Possibly overlaps above ar_lazy_preload
# https://github.com/nettofarah/graphql-query-resolver
# gem("graphql-query-resolver")

# Caching gems

# Persisted Queries. Backend will cache all the queries, while frontend will
# send the full query only when it's not found at the backend storage.
# Use with apollo persisted queries
# https://github.com/DmitryTsepelev/graphql-ruby-persisted_queries
# gem("graphql-persisted_queries")

# Cache response fragments: you can mark any field as cached
# https://github.com/DmitryTsepelev/graphql-ruby-fragment_cache
# gem("graphql-fragment_cache")

# Pagination & Connection gems

# Additional implementations of cursor-based paginations for GraphQL Ruby.
# Extends classes of graphql-ruby
# https://github.com/bibendi/graphql-connections
gem("graphql-connections")

# Implements page-based pagination returning collection and pagination metadata.
# It works with kaminari or other pagination tools implementing similar methods.
# https://github.com/RenoFi/graphql-pagination
# gem("graphql-pagination")
# gem("kaminari-activerecord")

group :test, :development do
  # Use byebug as debugging gem
  gem "byebug"

  # GraphiQL for GraphQL development
  gem "graphiql-rails"
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

group :development do
  # Calling `console` creates irb session in the browser (instead of the terminal)
  gem "web-console"

  # Use Rails DB to browse database at http://localhost:3000/rails/db/
  gem "rails_db"

  # Listen for development
  gem "listen", ">= 3.0.5", "< 3.2"

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem "spring"
  gem "spring-watcher-listen", "~> 2.0.0"
end
