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

  # Register custom output helpers (return HTML)
  # mark_safe: true tells Phlex to trust the output without checking SafeBuffer
  register_output_helper :show_title_id_badge, mark_safe: true
  register_output_helper :link_to_object, mark_safe: true
  register_output_helper :show_page_edit_icons, mark_safe: true
  register_output_helper :naming_vote_form, mark_safe: true
  register_output_helper :propose_naming_link, mark_safe: true
  register_output_helper :location_link, mark_safe: true
  register_output_helper :user_link, mark_safe: true
  register_output_helper :modal_link_to, mark_safe: true
  register_output_helper :put_button, mark_safe: true
  register_output_helper :link_icon, mark_safe: true
  register_output_helper :make_table, mark_safe: true
  register_output_helper :help_block_with_arrow, mark_safe: true
  register_output_helper :observation_location_help, mark_safe: true

  # Register custom value helpers (return values)
  register_value_helper :permission?
  register_value_helper :url_for
  register_value_helper :image_vote_as_short_string
  register_value_helper :image_vote_as_help_string
  register_value_helper :send_observer_question_tab
  register_value_helper :sequence_archive_options
  register_value_helper :add_q_param
  register_value_helper :add_args_to_url
  register_value_helper :controller_name
  register_value_helper :params

  # Enable fragment caching
  def cache_store
    Rails.cache
  end

  if Rails.env.development?
    def before_template
      comment { "Before #{self.class.name}" }
      super
    end
  end
end
