# frozen_string_literal: true

Rails.autoloaders.main.inflector.inflect(
  { "mo_paginator" => "MOPaginator",
    "gmap" => "GMap",
    "verify_api_key_email" => "VerifyAPIKeyMailer" }
)

Rails.autoloaders.main.ignore(
  "app/assets",
  "app/classes/api",
  "app/extensions",
  "app/javascripts",
  "app/views"
)

# These subdirs are for organization only, should not create new namespaces
FLATTEN_CLASSES_SUBDIRECTORIES = [
  %w[api2 error],
  %w[api2 core],
  %w[pattern_search error]
].freeze

Rails.autoloaders.each do |loader|
  FLATTEN_CLASSES_SUBDIRECTORIES.each do |subdir, subsub|
    loader.collapse("app/classes/#{subdir}/#{subsub}")
  end
end
