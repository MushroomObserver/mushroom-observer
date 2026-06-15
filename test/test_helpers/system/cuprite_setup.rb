# frozen_string_literal: true

# First, load Cuprite Capybara integration
require("capybara/cuprite")

# Then, we need to register our driver to be able to use it later
# with #driven_by method.
# https://sowenjub.me/writes/replacing-selenium-with-cuprite-for-rails-system-tests/
# If we re-register `:cuprite`, we get a conflict and settings are ignored
# :cuprite is registered by Rails already in version 7
# https://github.com/rubycdp/cuprite/issues/180
Capybara.register_driver(:mo_cuprite) do |app|
  # --no-sandbox and --disable-dev-shm-usage are required in Docker containers
  docker_options = if ENV["DOCKER"]
                     { "no-sandbox" => nil, "disable-dev-shm-usage" => nil }
                   else
                     {}
                   end

  Capybara::Cuprite::Driver.new(
    app,
    window_size: [1200, 800],
    browser_options: docker_options,
    # Increase Chrome startup wait time (required for stable CI builds)
    process_timeout: 15,
    # Enable debugging capabilities
    inspector: true,
    # Allow running Chrome in a headful mode by setting HEADLESS env
    # var to a falsey value
    headless: !ENV["HEADLESS"].in?(%w[n 0 no false])
  )
end
