# frozen_string_literal: true

# Adds CORS headers for API endpoints.
#
# Usage:
#   include CorsHeaders
#   before_action :set_cors_headers
#
# By default, allows GET, POST, OPTIONS methods. Override `cors_allowed_methods`
# to customize.
module CorsHeaders
  extend ActiveSupport::Concern

  ALLOWED_HEADERS = "Origin, X-Requested-With, Content-Type, Accept"
  DEFAULT_METHODS = %w[GET POST OPTIONS].freeze

  private

  def set_cors_headers
    response.set_header("Access-Control-Allow-Origin", "*")
    response.set_header("Access-Control-Allow-Headers", ALLOWED_HEADERS)
    response.set_header("Access-Control-Allow-Methods",
                        cors_allowed_methods.join(", "))
  end

  # Override in controller to restrict allowed methods
  def cors_allowed_methods
    DEFAULT_METHODS
  end
end
