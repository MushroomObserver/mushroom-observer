# frozen_string_literal: true

# Bootstrap modal with spinner for progress indicators (e.g.
# "saving vote"). Renders once in the application layout. Cannot be
# dismissed by user — must be hidden programmatically by JS, hence
# `keyboard: "false"` and `backdrop: "static"` on the modal root.
#
# Composes Components::Modal with `header: false` (no title bar,
# no close button) and a small dialog. The body holds the caption
# span that gets populated by `section-update:updated` window events
# plus the spinner. `aria-labelledby` points to the caption span so
# screenreaders announce the in-progress operation.
class Components::Modal::ProgressSpinner < Components::Base
  MODAL_ID = "modal_progress_spinner"
  BODY_ID = "#{MODAL_ID}_body".freeze
  CAPTION_ID = "#{MODAL_ID}_caption".freeze

  def view_template
    Modal(
      id: MODAL_ID,
      header: false,
      dialog_class: "modal-dialog modal-sm",
      body_class: "text-center",
      body_id: BODY_ID,
      title_id: CAPTION_ID,
      extra_data: {
        action: "section-update:updated@window->modal#hide",
        keyboard: "false",
        backdrop: "static"
      }
    ) do |m|
      m.with_body { render_caption_and_spinner }
    end
  end

  private

  def render_caption_and_spinner
    span(id: CAPTION_ID)
    span(class: "spinner-right mx-2")
  end
end
