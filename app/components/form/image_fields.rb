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
# Handles both upload images (temp_image) and existing images (good_image).
#
# @example
#   render Components::Form::ImageFields.new(
#     user: current_user,
#     image: @image,
#     img_id: 123,
#     upload: false
#   )
class Components::Form::ImageFields < Components::Base
  include Phlex::Rails::Helpers::FieldsFor

  # Properties
  prop :user, _Nilable(User)
  prop :image, _Nilable(::Image), default: nil
  prop :img_id, Integer, &:to_i
  prop :upload, _Boolean, default: false

  def view_template
    # Show upload messages for upload images
    upload_messages if @upload

    # Render form fields
    image_field = @upload ? :temp_image : :good_image

    fields_for(image_field) do |ffi|
      render_form_fields(ffi)
    end
  end

  private

  # Replaced by js
  def upload_messages
    div(class: "carousel-upload-messages") do
      span(class: "text-danger warn-text") { "" }
      span(class: "text-success info-text") { "" }
    end
  end

  def render_form_fields(form)
    fields = [
      render_notes_field(form),
      render_date_field(form),
      render_copyright_field(form),
      render_license_field(form)
    ]

    fields << render_original_name_field(form) unless @upload

    fields.join
  end

  def render_notes_field(form)
    text_area_with_label(
      form: form,
      field: :notes,
      index: @img_id,
      rows: 2,
      value: @image&.notes,
      label: :form_images_notes.l
    )
  end

  def render_date_field(form)
    date_select_with_label(
      form: form,
      field: :when,
      index: @img_id,
      value: @image&.when,
      object: @image,
      label: :form_images_when_taken.l
    )
  end

  def render_copyright_field(form)
    text_field_with_label(
      form: form,
      field: :copyright_holder,
      index: @img_id,
      value: @image&.copyright_holder,
      label: :form_images_copyright_holder.l
    )
  end

  def render_license_field(form)
    select_with_label(
      form: form,
      field: :license_id,
      index: @img_id,
      label: :form_images_select_license.t.html_safe, # rubocop:disable Rails/OutputSafety
      options: license_options,
      selected: selected_license
    )
  end

  def render_original_name_field(form)
    text_field_with_label(
      form: form,
      field: :original_name,
      index: @img_id,
      value: @image&.original_name,
      size: 40,
      label: :form_images_original_name.l
    )
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
