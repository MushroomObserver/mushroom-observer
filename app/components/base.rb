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

  # Register custom output helpers (return HTML)
  register_output_helper :show_title_id_badge
  register_output_helper :link_to_object
  register_output_helper :show_page_edit_icons
  register_output_helper :naming_vote_form
  register_output_helper :propose_naming_link
  register_output_helper :location_link
  register_output_helper :user_link
  register_output_helper :modal_link_to
  register_output_helper :put_button
  register_output_helper :text_area_with_label
  register_output_helper :date_select_with_label
  register_output_helper :text_field_with_label
  register_output_helper :select_with_label
  register_output_helper :link_icon
  register_output_helper :make_table
  register_output_helper :help_block_with_arrow

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

  # Renders trusted HTML content (I18n translations, Rails helpers,
  # formatted dates). Use this for content from:
  # - Translation strings (.t, .l)
  # - Rails helpers (user_link, link_to, etc.)
  # - Model methods that return safe HTML
  #
  # Do NOT use for user-generated content.
  #
  # @param content [ActiveSupport::SafeBuffer, String] HTML content
  # @return [void]
  def trusted_html(content)
    # rubocop:disable Rails/OutputSafety
    return raw(content) if content.is_a?(ActiveSupport::SafeBuffer)
    # rubocop:enable Rails/OutputSafety

    # Plain strings get escaped and output
    plain(content.to_s)
  end

  if Rails.env.development?
    def before_template
      comment { "Before #{self.class.name}" }
      super
    end
  end
end
