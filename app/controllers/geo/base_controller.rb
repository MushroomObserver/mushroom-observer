# frozen_string_literal: true

module Geo
  # Base controller for geographic services (elevation, geocoding, etc.)
  # These endpoints proxy external APIs to avoid exposing API keys
  # and to provide a stable interface.
  class BaseController < ApplicationController
    include CorsHeaders

    disable_filters
    before_action :set_cors_headers
    layout false

    private

    def render_error(message, status: :bad_request)
      render(json: { error: message }, status: status)
    end
  end
end
