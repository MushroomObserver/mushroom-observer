# frozen_string_literal: true

# Form for editing a user's profile.
# Renders name, location, notes, image upload, and mailing address fields.
# Upload fields use top-level `upload[...]` params (not nested under `user`)
# to match what the controller expects via params.dig(:upload, ...).
class Components::AccountProfileForm < Components::ApplicationForm
  # rubocop:disable Metrics/ParameterLists
  def initialize(model, copyright_holder:, copyright_year:,
                 licenses:, upload_license_id:, **)
    @copyright_holder = copyright_holder
    @copyright_year = copyright_year
    @licenses = licenses
    @upload_license_id = upload_license_id
    super(model, id: "account_profile_form", **)
  end
  # rubocop:enable Metrics/ParameterLists

  def around_template
    @attributes[:enctype] = "multipart/form-data"
    super
  end

  def form_action
    account_profile_path
  end

  def view_template
    super do
      submit(:profile_button.l, center: true)
      render_name_field
      render_place_name_field
      render_notes_field
      render_upload_fields
      render_mailing_address_field
      submit(:profile_button.l, center: true)
    end
  end

  private

  def render_name_field
    text_field(:name, label: "#{:profile_name.t}:")
  end

  def render_place_name_field
    autocompleter_field(:place_name, type: :location,
                                     label: "#{:profile_location.t}:",
                                     between: "(33%)")
  end

  def render_notes_field
    textarea_field(:notes, label: "#{:profile_notes.t}:",
                           rows: 10, between: "(33%)")
  end

  def render_upload_fields
    render_upload_image_field
    render_upload_copyright_holder
    render_upload_year
    render_upload_license
  end

  def render_mailing_address_field
    textarea_field(:mailing_address,
                   label: "#{:profile_mailing_address.t}:", rows: 5)
  end

  def render_upload_image_field
    file_component = FileField.new(
      upload_proxy(:image),
      attributes: {},
      wrapper_options: { label: image_file_label }
    )
    file_component.with_between { render_file_field_between }
    render(file_component)
  end

  def render_file_field_between
    span(class: "help-note") { plain("(33%)") }
    a(href: account_profile_select_image_path, class: "mx-2") do
      plain(:profile_image_reuse.t)
    end
  end

  def image_file_label
    key = model.image_id ? :profile_image_change : :profile_image_create
    "#{key.t}:"
  end

  def render_upload_copyright_holder
    render(TextField.new(
             upload_proxy(:copyright_holder, @copyright_holder),
             attributes: {},
             wrapper_options: { label: "#{:image_copyright_holder.l}:",
                                inline: true }
           ))
  end

  def render_upload_year
    render(SelectField.new(
             upload_proxy(:copyright_year, @copyright_year),
             collection: year_options,
             attributes: {},
             wrapper_options: { label: "#{:WHEN.l}:", inline: true }
           ))
  end

  def render_upload_license
    license_select = SelectField.new(
      upload_proxy(:license_id, @upload_license_id),
      collection: license_options,
      attributes: { selected: @upload_license_id },
      wrapper_options: { label: "#{:LICENSE.l}:", inline: true }
    )
    license_select.with_append { render_license_warning }
    render(license_select)
  end

  def render_license_warning
    div(class: "help-block") do
      plain("(")
      plain(:image_copyright_warning.t)
      plain(")")
    end
  end

  def upload_proxy(key, value = nil)
    FieldProxy.new("upload", key, value)
  end

  def year_options
    (1980..Time.zone.now.year).to_a.reverse.map { |y| [y.to_s, y] }
  end

  def license_options
    # Superform SelectField expects [value, display] — License returns
    # [display, id], so swap to [id, display]
    @licenses.map { |display, value| [value, display] }
  end
end
