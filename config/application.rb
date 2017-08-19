require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MushroomObserver
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W[
      #{config.root}/app/classes
      #{config.root}/app/extensions
    ]

# Tells rails not to generate controller-specific css and js stubs.
    config.generators.assets = false

    # Instruct ActionView how to mark form fields which have an error.
    # I just change the CSS class to "has_error", which gives it a red border.
    # This is superior to the default, which encapsulates the field in a div,
    # because that throws the layout off.  Just changing the border, while less
    # conspicuous, has no effect on the layout.  This is not a hack, this is
    # just a standard configuration many rails apps take advantage of.
    config.action_view.field_error_proc = proc { |html_tag, _instance|
      html_tag.sub(/(<\w+)/, '\1 class="has_error"').html_safe
    }
  end
end

MO = MushroomObserver::Application.config
require_relative("consts.rb")
