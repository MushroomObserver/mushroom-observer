# frozen_string_literal: true

Rails.autoloaders.main.inflector.inflect({
  # "api" => "API",
  # "api2" => "API2",
  "mo_paginator" => "MOPaginator",
  # "gm" => "GM",
  "gmap" => "GMap",
  "verify_api_key_email" => "VerifyAPIKeyEmail"
})

Rails.autoloaders.main.ignore(
  "app/assets",
  "app/classes/api/helpers",
  # "app/classes/api/error",
  # "app/classes/api",
  "app/classes/api2/helpers",
  # "app/classes/api2/error",
  # "app/classes/api2/upload",
  # "app/classes/api2",
  "app/classes/report",
  "app/controllers/ajax_controller",
  "app/controllers/name_controller",
  "app/controllers/observer_controller",
  "app/extensions",
  "app/javascripts",
  "app/models/comment",
  # "app/models/name",
  "app/models/queued_email",
  "app/views"
)

FLATTEN_ERROR_SUBDIRECTORIES = %w(
  api2
  pattern_search
)

Rails.autoloaders.each do |loader|
  FLATTEN_ERROR_SUBDIRECTORIES.each do |subdir|
    loader.collapse("app/classes/#{subdir}/error")
  end
end
