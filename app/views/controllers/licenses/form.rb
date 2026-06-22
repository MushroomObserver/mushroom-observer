# frozen_string_literal: true

module Views::Controllers::Licenses
  # Form for creating/editing licenses. Rendered directly by the
  # licenses controller's `new.rb` and `edit.rb`.
  class Form < ::Components::ApplicationForm
    def view_template
      render_display_name_field
      render_url_field
      render_deprecated_checkbox
      submit(:SUBMIT.t, center: true)
    end

    private

    # Automatically determine action URL based on whether record is
    # persisted.
    def form_action
      return licenses_path if model.nil? || !model.persisted?

      license_path(model)
    end

    def render_display_name_field
      text_field(:display_name, label: "#{:license_display_name.t}:",
                                data: { autofocus: true }) do |f|
        f.with_append do
          render(::Components::Help::Block.new(:license_display_name_help.t))
        end
      end
    end

    def render_url_field
      text_field(:url, label: "#{:license_url.t}:") do |f|
        f.with_append do
          render(::Components::Help::Block.new(:license_url_help.t))
        end
      end
    end

    def render_deprecated_checkbox
      checkbox_field(:deprecated, label: :license_form_checkbox_deprecated.t)
    end
  end
end
