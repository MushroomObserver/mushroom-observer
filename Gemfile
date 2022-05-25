def next?
  File.basename(__FILE__) == "Gemfile.next"
end
# frozen_string_literal: true

source("https://rubygems.org")

# security fix for CVE-2021-41817 regex denial of service vulnerability
gem("date", ">= 3.2.1")

gem("sprockets")

# To bundle edge Rails instead: gem "rails", github: "rails/rails"
gem("rails", "~> 6.0.4")
# Toolkit to upgrade Rails application
# It will help set up dual booting, track deprecation warnings,
# and get a report on outdated dependencies for any Rails application.
gem("next_rails")

# This is here only to ensure a patch for a code injection vulnerability.
# Please remove next time we update everything.
# gem("activestorage", ">= 5.2.6.3")

# Use mysql2 as db connector
# See https://github.com/brianmario/mysql2
gem("mysql2")

# Use sqlite3 as the database for Active Record
# gem("sqlite3")

# Add Arel helpers for more concise query syntax in Arel
# https://github.com/camertron/arel-helpers
# https://github.com/Faveod/arel-extensions
gem("arel_extensions")
gem("arel-helpers")

# Add method `mass_insert` for bulk db inserts in ActiveRecord.
# Same basic syntax as upcoming Rails 6 `insert_all`
# If upgrading to Rails 6, we can disable the gem and switch methods
gem("mass_insert")

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
# gem("turbolinks")

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem("jbuilder")

# Use ActiveModel has_secure_password
# gem("bcrypt", "~> 3.1.7")

# Use unicorn as the app server
gem("unicorn", "5.4.1")

# Use Capistrano for deployment
# gem("capistrano", group: :development)

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

# Slick Slider for Image Carousel
# See https://github.com/kenwheeler/slick/
#     https://github.com/bodrovis/jquery-slick-rails
gem("jquery-slick-rails")

# email generation, parsing and sending
gem("mail")

# for detecting file type of uploaded images
gem("mimemagic")

# for creating zip files
gem("rubyzip")

# to handle frontend requests from different port, e.g. dev GraphQL client
gem("rack-cors")

########## Development, Testing, and Analysis ##################################

# Use built-in Ruby coverage to generate html coverage file
gem("simplecov", require: false)
# generate lcov file to send to Coveralls by Github Actions
gem("simplecov-lcov", require: false)

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
gem("rubocop", "= 0.89.0", require: false)
gem("rubocop-performance", ">= 1.8.1")
gem("rubocop-rails", ">= 2.8.1") # version of rubocop-rails for older rubocop
# Rubocop extension for enforcing graphql-ruby best practices.
# You need to tell RuboCop to load the GraphQL extension. rubocop.yml
# require:
#  - rubocop-other-extension
#  - rubocop-graphql
# http://github.com/DmitryTsepelev/rubocop-graphql
gem("rubocop-graphql", require: false)

# use mry to support safe updating of .rubocop.yml
gem("mry", require: false)

########## GraphQL API ########################################

# GraphQL-Ruby
# https://github.com/rmosolgo/graphql-ruby
gem("graphql")
#
# Note: Some of the following gems are experimental at this point 1/22
#
# Debug future changes in GraphQL API
# Takes two GraphQL schemas and outputs a list of changes between versions
# gem("graphql-schema_comparator")
#
# Authorization gem
# Action Policy is an authorization library for your GraphQL Ruby application
# gem("action_policy-graphql")
#
# Pagination & Connection gems
#
# Additional implementations of cursor-based paginations for GraphQL Ruby.
# Extends classes of graphql-ruby
# Use with GraphQL::Connections::Stable
# https://github.com/bibendi/graphql-connections
gem("graphql-connections")
#
# Allows cursor pagination through an ActiveRecord relation.
# Supports ordering by any column, ascending or descending.
# Use with the RailsCursorPagination::Paginator class.
# https://github.com/xing/rails_cursor_pagination
# gem("rails_cursor_pagination")
#
# Implements page-based pagination returning collection and pagination metadata.
# It works with kaminari or other pagination tools implementing similar methods.
# https://github.com/RenoFi/graphql-pagination
# gem("graphql-pagination")
# gem("kaminari-activerecord")
#
# Dataloading gems
# Note that dataloader comes shipped with graphql gem as of 1.12
# It's also experimental. Below are some alternatives
# https://evilmartians.com/chronicles/how-to-graphql-with-ruby-rails-active-record-and-no-n-plus-one
#
# Provides an executor for the graphql gem which allows queries to be batched.
# Defined in loaders/record_loader.rb RecordLoader < GraphQL::Batch::Loader
# Used in queries and resolvers like
# def product(id:) RecordLoader.for(Product).load(id)
# def products(ids:) RecordLoader.for(Product).load_many(ids)
# https://github.com/Shopify/graphql-batch
gem("graphql-batch")
#
# Brings association lazy load functionality to your Rails applications
# Use like User.lazy_preload(:posts).limit(10)
# https://github.com/DmitryTsepelev/ar_lazy_preload
# gem("ar_lazy_preload")
#
# (Similar to graphql-batch and maybe ar_lazy_preload. Maybe better?)
# Provides a generic lazy batching mechanism to avoid N+1 DB queries,
# HTTP queries, etc.
# https://github.com/exAspArk/batch-loader
# https://github.com/exAspArk/batch-loader#alternatives
# gem("batch-loader")
#
# (Similar to ar_lazy_preload)
# Old add-on to graphql-ruby that allows your field resolvers to minimize N+1
# SELECTS issued by ActiveRecord. Possibly overlaps above ar_lazy_preload
# https://github.com/nettofarah/graphql-query-resolver
# gem("graphql-query-resolver")
#
# Caching gems
#
# Persisted Queries. Backend will cache all the queries, while frontend will
# send the full query only when it's not found at the backend storage.
# Use with apollo persisted queries
# https://github.com/DmitryTsepelev/graphql-ruby-persisted_queries
# gem("graphql-persisted_queries")
#
# Cache response fragments: you can mark any field as cached
# https://github.com/DmitryTsepelev/graphql-ruby-fragment_cache
# gem("graphql-fragment_cache")
#
# Need to cache and instrument your GraphQL code in Ruby? Look no further!
# https://github.com/chatterbugapp/cacheql
# gem("cacheql")
#

group :test, :development do
  # Use byebug as debugging gem
  gem("byebug")

  # GraphiQL for GraphQL development
  # Makes an IDE available to test graphql queries at '/graphiql/'
  # Until current changes are released, need to use this Github version:
  gem("graphiql-rails", github: "rmosolgo/graphiql-rails", ref: "6b34eb1")
end

group :test do
  # Use capybara to simulate user-browser interaction
  gem("capybara", "~> 3.36.0") # for ruby 2.6

  # allows test results to be reported back to test runner IDE's
  gem("minitest")
  gem("minitest-reporters")

  # Mocking and stubbing in Ruby
  gem("mocha")

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
  gem("rails_db", "~> 2.4.0")

  # Additional generators for input types, search objects, and mutations
  # gem("graphql-rails-generators")
end
