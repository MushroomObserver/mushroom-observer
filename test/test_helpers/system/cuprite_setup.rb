# frozen_string_literal: true

# First, load Cuprite Capybara integration
require("capybara/cuprite")

# Ferrum 0.20's legacy JS-eval path prints a [Ferrum] DEPRECATION
# warning to STDOUT for any execute_script call it thinks might
# return a promise (Capybara's scroll_to, which calls scrollIntoView,
# is one). NoTestConsoleNoise fails any passing test that prints
# anything. FERRUM_JS_API=new routes every call through the path that
# waits for/returns the value instead of the legacy {} stand-in,
# which is what the deprecation warns about -- no caller here reads
# execute_script's return value, so this has no other effect.
ENV["FERRUM_JS_API"] = "new"

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
