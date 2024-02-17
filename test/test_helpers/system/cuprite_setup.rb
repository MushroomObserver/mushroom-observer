# frozen_string_literal: true

# First, load Cuprite Capybara integration
require "capybara/cuprite"

# Then, we need to register our driver to be able to use it later
# with #driven_by method.
# https://sowenjub.me/writes/replacing-selenium-with-cuprite-for-rails-system-tests/
# If we re-register `:cuprite`, we get a conflict and settings are ignored
# :cuprite is registered by Rails already in version 7
# https://github.com/rubycdp/cuprite/issues/180
Capybara.register_driver(:mo_cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [1200, 800],
    # See additional options for Dockerized environment in the respective
    # section of this article
    browser_options: {},
    # Increase Chrome startup wait time (required for stable CI builds)
    process_timeout: 10,
    # Enable debugging capabilities
    inspector: true,
    # Allow running Chrome in a headful mode by setting HEADLESS env
    # var to a falsey value
    headless: !ENV["HEADLESS"].in?(%w[n 0 no false])
  )
end
