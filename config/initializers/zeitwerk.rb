# frozen_string_literal: true

Rails.autoloaders.main.inflector.inflect({
  "mo_paginator" => "MOPaginator",
  "gmap" => "GMap",
  "verify_api_key_email" => "VerifyAPIKeyEmail"
})

Rails.autoloaders.main.ignore(
  "app/assets",
  "app/classes/api/helpers",

  "app/extensions",
  "app/javascripts",

  "app/views"
)

FLATTEN_CLASSES_SUBDIRECTORIES = [
  %w(api2 error),
  %w(api2 helpers),
  %w(pattern_search error)
]

Rails.autoloaders.each do |loader|
  FLATTEN_CLASSES_SUBDIRECTORIES.each do |subdir, subsub|
    loader.collapse("app/classes/#{subdir}/#{subsub}")
  end
end
