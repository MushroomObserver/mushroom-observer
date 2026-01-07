# frozen_string_literal: true

# Form fields for editing image metadata in the observation form.
#
# Fields include:
# - Notes (text area)
# - When taken (date select)
# - Copyright holder (text field)
# - License (select)
# - Original name (text field, existing images only)
#
# Handles both upload images (image) and existing images (good_image).
# Uses FieldProxy to generate field names/IDs without requiring a form object.
#
# @example
#   render Components::FormImageFields.new(
#     user: @user,
#     image: @image,
#     img_id: 123,
#     upload: false
#   )
class Components::FormImageFields < Components::Base
  # Properties
  prop :user, _Nilable(User)
  prop :image, _Nilable(::Image), default: nil
  prop :img_id, Integer, &:to_i
  prop :upload, _Boolean, default: false

  def view_template
    upload_messages if @upload
    render_form_fields
  end

  private

  # Replaced by js
  def upload_messages
    div(class: "carousel-upload-messages") do
      span(class: "text-danger warn-text") { "" }
      span(class: "text-success info-text") { "" }
    end
  end

  def render_form_fields
    render_notes_field
    render_date_field
    render_copyright_field
    render_license_field
    render_original_name_field unless @upload
  end

  def render_notes_field
    field = image_field_proxy(:notes, @image&.notes)
    render(Components::ApplicationForm::TextareaField.new(
             field,
             attributes: { rows: 2 },
             wrapper_options: { label: :form_images_notes.l }
           ))
  end

  def render_date_field
    field = image_field_proxy(:when, @image&.when)
    render(Components::ApplicationForm::DateField.new(
             field,
             attributes: { value: @image&.when },
             wrapper_options: { label: :form_images_when_taken.l }
           ))
  end

  def render_copyright_field
    field = image_field_proxy(:copyright_holder, @image&.copyright_holder)
    render(Components::ApplicationForm::TextField.new(
             field,
             attributes: {},
             wrapper_options: { label: :form_images_copyright_holder.l }
           ))
  end

  def render_license_field
    field = image_field_proxy(:license_id, selected_license)
    render(Components::ApplicationForm::SelectField.new(
             field,
             collection: superform_license_options,
             attributes: {},
             wrapper_options: { label: :form_images_select_license.t.html_safe } # rubocop:disable Rails/OutputSafety
           ))
  end

  def render_original_name_field
    field = image_field_proxy(:original_name, @image&.original_name)
    render(Components::ApplicationForm::TextField.new(
             field,
             attributes: { size: 40 },
             wrapper_options: { label: :form_images_original_name.l }
           ))
  end

  def image_field_proxy(field_key, value)
    image_type = @upload ? :image : :good_image
    Components::ApplicationForm.image_field_proxy(image_type, @img_id, field_key,
                                                  value)
  end

  # Superform expects [value, display] but Rails returns [display, value]
  def superform_license_options
    license_options.map { |display, value| [value, display] }
  end

  def license_options
    if @upload || @image.nil?
      License.available_names_and_ids(@user&.license)
    else
      License.available_names_and_ids(@image&.license)
    end
  end

  def selected_license
    if @upload || @image.nil?
      @user&.license_id
    else
      @image&.license_id
    end
  end
end
