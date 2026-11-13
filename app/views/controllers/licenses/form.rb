# frozen_string_literal: true

module Views::Controllers::Licenses
  # Form for creating/editing licenses. Rendered directly by the
  # licenses controller's `new.rb` and `edit.rb`.
  class Form < ::Components::ApplicationForm
    def view_template
      render_display_name_field
      render_url_field
      render_deprecated_checkbox
      submit(:submit.ti, center: true)
    end

    private

    # Automatically determine action URL based on whether record is
    # persisted.
    def form_action
      return licenses_path if model.nil? || !model.persisted?

      license_path(model)
    end

    def render_display_name_field
      text_field(:display_name, label: :license_display_name,
                                data: { autofocus: true }) do |f|
        f.with_append do
          Help(content: :license_display_name_help.t)
        end
      end
    end

    def render_url_field
      text_field(:url, label: :url, type: "url") do |f|
        f.with_append do
          Help(content: :license_url_help.t)
        end
      end
    end

    def render_deprecated_checkbox
      checkbox_field(:deprecated, label: :deprecated.ti, wrap_class: "mb-3")
    end
  end
end
