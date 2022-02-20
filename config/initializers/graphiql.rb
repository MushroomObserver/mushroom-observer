# frozen_string_literal: true

# https://github.com/rmosolgo/graphiql-rails

if Rails.env.development?
  GraphiQL::Rails.config.headers["X-GraphiQL-Request"] = ->(_context) { "true" }
  # GraphiQL::Rails.config.headers["Authorization"] = ->(context) {
  #   "bearer #{context.session["token"]}"
  # }
  GraphiQL::Rails.config.query_params = false
  # GraphiQL::Rails.config.initial_query = nil
  # GraphiQL::Rails.config.title = nil
  # GraphiQL::Rails.config.logo = nil
  # GraphiQL::Rails.config.csrf = true
  GraphiQL::Rails.config.header_editor_enabled = true
end
