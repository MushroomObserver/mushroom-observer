source "https://rubygems.org"

# To bundle edge Rails instead: gem "rails", github: "rails/rails"
gem "rails", "~> 4.0.0"
gem "mysql2"
gem "jquery-rails"

# Only needed by production server, but simplest to always have it here.
gem "unicorn"

gem "i18n"
gem "test-unit"
gem "RedCloth"
gem "blankslate"
gem "browser"
gem "rtf"
gem "cure_acts_as_versioned"
gem "coveralls", require: false

group :test do
  gem "fakeweb", "~> 1.3"
  gem "rails-perftest"
  gem "ruby-prof"
  gem "rubocop"
end

group :development, :test do
  gem "byebug"
end

group :assets do
  gem "sass-rails",   "~> 4.0"
  gem "coffee-rails", "~> 4.0"
  gem "uglifier",     ">= 1.0.3"
end
