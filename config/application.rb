require File.expand_path("../boot", __FILE__)

require "rails/all"

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

module MushroomObserver
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(
      #{::Rails.root}/app/classes
      #{::Rails.root}/app/extensions
    )

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join("my", "locales", "*.{rb,yml}").to_s]
    # config.i18n.default_locale = :de
    config.i18n.enforce_available_locales = false

    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]
    
    # This instructs ActionView how to mark form fields which have an error.
    # I just change the CSS class to "has_error", which gives it a red border.
    # This is superior to the default, which encapsulates the field in a div,
    # because that throws the layout off.  Just changing the border, while less
    # conspicuous, has no effect on the layout.  This is not a hack, this is
    # just a standard configuration many rails apps take advantage of.
    config.action_view.field_error_proc = Proc.new { |html_tag, instance|
      html_tag.sub(/(<\w+)/, '\1 class="has_error"').html_safe
    }
    
    # Minimal asset configuration.
    config.assets.enabled = true
    config.assets.version = "1.0"
  end
end

PRODUCTION  = (ENV["RAILS_ENV"] == 'production')
DEVELOPMENT = (ENV["RAILS_ENV"] == 'development')
TESTING     = (ENV["RAILS_ENV"] == 'test')

MO = MushroomObserver::Application.config
require File.expand_path("../consts.rb", __FILE__)
