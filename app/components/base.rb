# frozen_string_literal: true

class Components::Base < Phlex::HTML
  extend Literal::Properties

  # Include any helpers you want to be available across all components
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::LinkTo

  # Register custom output helpers (return HTML)
  register_output_helper :show_title_id_badge
  register_output_helper :naming_vote_form
  register_output_helper :propose_naming_link
  register_output_helper :location_link
  register_output_helper :user_link
  register_output_helper :mark_as_reviewed_toggle
  register_output_helper :modal_link_to
  register_output_helper :image_info
  register_output_helper :put_button
  register_output_helper :text_area_with_label
  register_output_helper :date_select_with_label
  register_output_helper :text_field_with_label
  register_output_helper :select_with_label

  # Register custom value helpers (return values)
  register_value_helper :permission?
  register_value_helper :url_for
  register_value_helper :image_vote_as_short_string
  register_value_helper :image_vote_as_help_string
  register_value_helper :send_observer_question_tab

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
