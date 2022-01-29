# Be sure to restart your server when you modify this file.

# frozen_string_literal: true

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests. A different port is considered cross-origin.

# Read more: https://github.com/cyu/rack-cors

MushroomObserver::Application.config.middleware.insert_before(0, Rack::Cors) do
  allow do
    # allow /graphql access only from localhost:3001
    origins "http://localhost:3001"
    resource "/graphql", headers: :any, methods: [:get, :post, :patch, :put, :delete, :options, :head]
  end
end
