# frozen_string_literal: true

# Upload section of the observation form. Renders image select
# button and hidden fields for image management. Sub-component of
# `Views::Controllers::Observations::Form`.
#
# @param form [Components::ApplicationForm] the parent form
# @param good_images [Array<Image>] already uploaded images
class Views::Controllers::Observations::Form::Upload < Views::Base
  prop :form, ::Components::ApplicationForm
  prop :good_images, _Array(::Image), default: -> { [] }

  def view_template
    h4(class: "panel-title d-inline-block mr-4") { :IMAGES.l }
    render_file_select_button
    render_good_image_ids_field
    render_thumb_image_id_field
  end

  private

  def render_file_select_button
    field_proxy = Components::ApplicationForm::FieldProxy.new(
      "", :select_images_button, nil
    )
    render(
      Components::ApplicationForm::FileField.new(
        field_proxy,
        multiple: true,
        controller: "form-images",
        action: "change->form-images#addSelectedFiles",
        wrapper_options: { label: false }
      )
    )
  end

  def render_good_image_ids_field
    # Nested under observation[] for Superform param consistency
    input(
      type: "hidden",
      name: "observation[good_image_ids]",
      value: @good_images.map(&:id).join(" "),
      data: { form_images_target: "goodImageIds" }
    )
  end

  # Static hidden sidecar for `observation[thumb_image_id]`. Ensures
  # the param is *always* submitted (defaulting to ""), so removing
  # the currently-selected thumb image without picking another one
  # clears the model field rather than retaining a now-deleted image
  # id. The actual thumb selection is the checked radio in
  # `FormCarouselItem#button_to_set_thumb_img`; the radios share the
  # same `name`, are posted AFTER this hidden in form order, and the
  # checked one's value wins in Rails' param parsing.
  def render_thumb_image_id_field
    input(type: "hidden", name: "observation[thumb_image_id]",
          value: "", autocomplete: "off")
  end
end
