require File.expand_path('../boot', __FILE__)

require 'rails/all'

APP_ROOT = File.expand_path('../..', __FILE__)

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

# Short-hand for the three execution modes.
PRODUCTION  = (::Rails.env == 'production')
DEVELOPMENT = (::Rails.env == 'development')
TESTING     = (::Rails.env == 'test')

# Should be one of [:normal, :silent]
# :silent turns off event logging and email notifications
class RunLevel
  @@runlevel = :normal
  def self.normal()
    @@runlevel = :normal
  end
  
  def self.silent()
    @@runlevel = :silent
  end
  
  def self.is_normal?()
    @@runlevel == :normal
  end
end

# RUN_LEVEL = :normal # :silent

def import_constants(file)
  file = File.join(File.dirname(__FILE__), file)
  if File.exists?(file)
    Module.new do
      class_eval File.read(file, :encoding => 'utf-8')
      for const in constants
        unless Object.const_defined?(const)
          Object.const_set(const, const_get(const))
        end
      end
    end
  end
end

import_constants('consts-site.rb')
import_constants('consts.rb')

module MushroomObserver
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(
      #{::Rails.root.to_s}/app/classes
      #{::Rails.root.to_s}/app/extensions
    )

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Make Active Record use UTC instead of local time.  This is critical if we
    # want to sync up remote servers.  It causes Rails to store dates in UTC and
    # convert from UTC to whatever we've set the timezone to when reading them
    # back in.  It shouldn't actually make any difference how the database is
    # configured.  It takes dates as a string, stores them however it chooses,
    # performing whatever conversions it deems fit, then returns them back to us
    # in exactly the same format we gave them to it.  (NOTE: only the first line
    # should be necessary, but for whatever reason, Rails is failing to do the
    # other configs on some platforms.)
    config.time_zone = SERVER_TIME_ZONE
    if config.time_zone.nil?
      raise 'TZ environment variable must be set. Run "rake -D time" for a list of tasks for finding appropriate time zone names.'
    end

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

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

    # Configure SMTP settings for ActionMailer.
    config.action_mailer.smtp_settings = MAIL_CONFIG
    
    # Minimal asset configuration.
    config.assets.enabled = true
    config.assets.version = '1.0'
  end
end
