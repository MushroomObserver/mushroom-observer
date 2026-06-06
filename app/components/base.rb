# frozen_string_literal: true

class Components::Base < Phlex::HTML
  extend Literal::Properties

  # Include any helpers you want to be available across all components
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::ClassNames
  include Phlex::Rails::Helpers::TurboFrameTag
  include Components::TrustedHtml

  # Register custom value helpers (return values)
  register_value_helper :permission?
  register_value_helper :in_admin_mode?
  register_value_helper :url_for
  register_value_helper :image_vote_as_short_string
  register_value_helper :image_vote_as_help_string
  register_value_helper :sequence_archive_options
  register_value_helper :add_q_param
  register_value_helper :q_param
  register_value_helper :add_args_to_url
  register_value_helper :controller_name
  register_value_helper :controller_path
  register_value_helper :action_name
  register_value_helper :params

  # Enable fragment caching
  def cache_store
    Rails.cache
  end

  def before_template
    comment { "Before #{self.class.name}" } if Rails.env.development?
    super
  end
end
