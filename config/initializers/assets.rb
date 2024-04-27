# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder
# are already added.
# Rails.application.config.assets.paths << Rails.root.join("app/javascript")
# Rails.application.config.assets.precompile += %w( search.js  jquery.min.js)
Rails.application.config.assets.precompile += %w[bootstrap.min.js]
Rails.app.config.assets.precompile <<
  %r{bootstrap/glyphicons-halflings-regular\.(?:eot|svg|ttf|woff2?)$}
