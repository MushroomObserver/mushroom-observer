# frozen_string_literal: true

# Upload section of the observation form.
# Renders image select button and hidden fields for image management.
#
# @param form [Components::ApplicationForm] the parent form
# @param good_images [Array<Image>] already uploaded images
class Components::ObservationFormUpload < Components::Base
  include Phlex::Rails::Helpers::FileFieldTag

  prop :form, _Any
  prop :good_images, _Array(Image), default: -> { [] }

  def view_template
    h4(class: "panel-title d-inline-block mr-4") { :IMAGES.l }
    render_file_select_button
    render_good_image_ids_field
    render_thumb_image_id_field
  end

  private

  def render_file_select_button
    label(for: "select_images_button", class: "btn btn-default file-field") do
      trusted_html(:select_file.l)
      file_field_tag(
        :select_images_button,
        multiple: true,
        accept: "image/*",
        data: { action: "change->form-images#addSelectedFiles" }
      )
    end
  end

  def render_good_image_ids_field
    # Not a model attribute, just a standalone hidden field
    input(
      type: "hidden",
      name: "good_image_ids",
      value: @good_images.map(&:id).join(" "),
      data: { form_images_target: "goodImageIds" }
    )
  end

  def render_thumb_image_id_field
    render(
      @form.field(:thumb_image_id).text(
        type: "hidden",
        data: { form_images_target: "thumbImageId" }
      )
    )
  end
end
