# frozen_string_literal: true

# Local caching defaults to off (config/environments/development.rb),
# unlike production -- so a real N+1-cache-round-trip bug (#4865) can
# go unnoticed locally for a long time. Printed once at server/console
# boot by config/initializers/warn_if_dev_cache_disabled.rb.
class DevCacheWarning
  MESSAGE = "\n*** Caching is OFF -- this doesn't match production. Run " \
            "`bin/rails dev:cache` to toggle it on (creates " \
            "tmp/caching-dev.txt) and catch cache-related bugs locally; " \
            "run it again to toggle back off if you're editing views/" \
            "components and want to see changes to cached HTML " \
            "immediately. If you want caching on AND to see an updated " \
            "fragment, run `Rails.cache.clear` from `bin/rails console` " \
            "instead of toggling. ***\n"

  # Only a server/console boot gets the reminder -- rake tasks
  # (migrations, asset precompile, etc.) also load initializers under
  # RAILS_ENV=development and shouldn't get an unrelated warning line
  # in their output.
  def self.applicable?(
    env: Rails.env,
    server_or_console: !!(defined?(Rails::Server) || defined?(Rails::Console)),
    cache_file_exists: Rails.root.join("tmp/caching-dev.txt").exist?
  )
    env.development? && server_or_console && !cache_file_exists
  end

  def self.warn_if_applicable
    warn(MESSAGE) if applicable?
  end
end
