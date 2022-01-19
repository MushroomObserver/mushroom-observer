# frozen_string_literal: true

require(File.expand_path("boot", __dir__))

require("rails/all")

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MushroomObserver
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those
    # specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W[
      #{config.root}/app/classes
      #{config.root}/app/extensions
    ]

    # Set Time.zone default to the specified zone and
    # make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names.
    # Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from
    # config/locales/*.rb, yml are auto loaded.
    # config.i18n.load_path +=
    #  Dir[Rails.root.join("my", "locales", "*.{rb,yml}").to_s]
    # config.i18n.default_locale = :de
    config.i18n.enforce_available_locales = true

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Tells rails not to generate controller-specific css and js stubs.
    config.generators.assets = false

    # This instructs ActionView how to mark form fields which have an error.
    # I just change the CSS class to "has_error", which gives it a red border.
    # This is superior to the default, which encapsulates the field in a div,
    # because that throws the layout off.  Just changing the border, while less
    # conspicuous, has no effect on the layout.  This is not a hack, this is
    # just a standard configuration many rails apps take advantage of.
    config.action_view.field_error_proc = proc { |html_tag, _instance|
      html_tag.sub(/(<\w+)/, '\1 class="has_error"').html_safe
    }

    # Still validating 5.2 deploy and want to allow rollback
    # TODO: Remove this once we are satisfied with 5.2 deplay.
    config.action_dispatch.use_authenticated_cookie_encryption = false
  end
end

MO = MushroomObserver::Application.config
require(File.expand_path("consts.rb", __dir__))
