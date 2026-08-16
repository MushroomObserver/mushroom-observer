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
    div(class: "d-flex flex-wrap align-items-center") do
      render_drop_hint
      render_file_select_button
      render_take_photo_button
    end
    render_good_image_ids_field
    render_thumb_image_id_field
  end

  private

  # Says out loud what the form already does: the whole form is the
  # drop target (see form-images_controller.js), and paste works
  # anywhere too. Hidden on touch devices -- there's no drag source
  # there, and the buttons speak for themselves.
  def render_drop_hint
    span(class: "drop-paste-hint mr-3") do
      plain(:drop_or_paste_images.l)
    end
  end

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
        wrapper_options: { label: false, button_text: :select_photos.l }
      )
    )
  end

  # Android's system photo picker has no camera option (iOS builds one
  # into its picker), so a dedicated capture input is the only way to
  # photograph a slip straight from the form there. `capture` opens the
  # rear camera directly on both platforms -- one shot per tap, feeding
  # the same handler as the file picker. No `multiple`: a capture
  # returns a single photo by nature. Hidden on non-touch devices via
  # `.take-photo-field` (see _form_elements.scss) -- desktop browsers
  # ignore `capture` and the button would just duplicate the picker.
  def render_take_photo_button
    field_proxy = Components::ApplicationForm::FieldProxy.new(
      "", :take_photo_button, nil
    )
    render(
      Components::ApplicationForm::FileField.new(
        field_proxy,
        capture: "environment",
        controller: "form-images",
        action: "change->form-images#addSelectedFiles",
        # No vertical margin of its own: the wrapper has to match the
        # select field's plain form-group box, or the two buttons sit
        # at different heights in the align-items-center row.
        wrapper_options: { label: false, button_text: :take_photo.l,
                           wrap_class: "ml-3 take-photo-field" }
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
  # `Form::UploadGallery::Item#button_to_set_thumb_img`; the radios share the
  # same `name`, are posted AFTER this hidden in form order, and the
  # checked one's value wins in Rails' param parsing.
  def render_thumb_image_id_field
    input(type: "hidden", name: "observation[thumb_image_id]",
          value: "", autocomplete: "off")
  end
end
