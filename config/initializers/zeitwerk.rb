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
  "app/classes/api2/helpers",
  "app/controllers/ajax_controller",
  "app/controllers/name_controller",
  "app/controllers/observer_controller",
  "app/extensions",
  "app/javascripts",
  "app/models/comment",
  "app/models/image",
  "app/models/name",
  "app/models/observation",
  "app/models/queued_email",
  "app/views"
)
