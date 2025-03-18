# frozen_string_literal: true

# This file is used to start a Rack-based standalone server for ActionCable
# Start our cable server with `bundle exec puma -p 28080 cable/config.ru`

require_relative "../config/environment"
Rails.application.eager_load!

run ActionCable.server
