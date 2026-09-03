# frozen_string_literal: true

module Views::Controllers::Account::Profile
  # Form for editing a user's profile. Rendered by the
  # account/profile controller's `edit.rb`. Renders name,
  # location, notes, image upload, and mailing address fields. Upload
  # fields are nested under user[upload][...] via ApplicationForm's
  # upload_fields helper (namespace(:upload) inside the user form).
  class Form < ::Components::ApplicationForm
    prop :copyright_holder, String
    prop :copyright_year, Integer
    prop :licenses, _Array(_Tuple(String, Integer))
    prop :upload_license_id, _Nilable(Integer)

    def initialize(model, **)
      super(model, id: "account_profile_form", **)
    end

    def around_template
      @attributes[:enctype] = "multipart/form-data"
      super
    end

    def form_action
      account_profile_path
    end

    def view_template
      super do
        submit(:update.ti, center: true)
        render_name_field
        render_place_name_field
        render_notes_field
        render_upload_fields
        render_mailing_address_field
        submit(:update.ti, center: true)
      end
    end

    private

    def render_name_field
      text_field(:name, label: :name.ti)
    end

    def render_place_name_field
      autocompleter_field(:place_name, type: :location,
                                       label: :profile_location,
                                       label_appends: "(33%)")
    end

    def render_notes_field
      textarea_field(:notes, label: :profile_notes,
                             rows: 10, label_appends: "(33%)")
    end

    def render_upload_fields
      upload_fields(
        file_field_label: image_file_label,
        copyright_holder: @copyright_holder,
        copyright_year: @copyright_year,
        licenses: @licenses,
        upload_license_id: @upload_license_id
      ) { render_file_field_between }
    end

    def render_mailing_address_field
      textarea_field(:mailing_address,
                     label: :profile_mailing_address, rows: 5)
    end

    def render_file_field_between
      Help(element: :span, content: "(33%)")
      a(href: account_profile_select_image_path, class: "mx-2") do
        plain(:profile_image_reuse.t)
      end
    end

    def image_file_label
      key = model.image_id ? :profile_image_change : :profile_image_create
      key.t
    end
  end
end
