# frozen_string_literal: true

# Form for creating/editing licenses
class Components::LicenseForm < Components::ApplicationForm
  def view_template
    render_display_name_field
    render_url_field
    render_deprecated_checkbox
    submit(:SUBMIT.t, center: true)
  end

  private

  # Automatically determine action URL based on whether record is persisted
  def form_action
    return view_context.licenses_path if model.nil? || !model.persisted?

    view_context.license_path(model)
  end

  def render_display_name_field
    text_field(:display_name, label: "#{:license_display_name.t}:",
                              data: { autofocus: true },
                              append: display_name_help)
  end

  def render_url_field
    text_field(:url, label: "#{:license_url.t}:",
                     append: url_help)
  end

  def render_deprecated_checkbox
    checkbox_field(:deprecated, label: :license_form_checkbox_deprecated.t)
  end

  def display_name_help
    div(class: "help-block") { :license_display_name_help.t }
  end

  def url_help
    div(class: "help-block") { :license_url_help.t }
  end
end
