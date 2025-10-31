# frozen_string_literal: true

# Set up gems listed in the Gemfile.
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require("bundler/setup") if File.exist?(ENV["BUNDLE_GEMFILE"])

# Strict Ivars raises a NameError when you read an undefined instance varaible
# Reduces sneaky view errors from unexpected nils
require("strict_ivars")
