# frozen_string_literal: true

# Bootstrap modal for Turbo confirmation dialogs.
# Replaces the browser's native confirm() with a styled modal.
# Used by Turbo.config.forms.confirm via the confirm-modal Stimulus
# controller.
#
# Renders once in the application layout. The `confirm-modal` Stimulus
# controller mutates the title element's text and the confirm button's
# action target at runtime.
#
# Headerless on purpose: the title element lives inside `.modal-body`
# (with the standard `.modal-title` styling) so the Stimulus controller
# can reuse the same target convention as other modals while the body
# stays vertically centered. `aria-labelledby` still points to the
# in-body title via the modal's existing title_id default.
class Components::ModalConfirm < Components::Base
  MODAL_ID = "mo_confirm"
  TITLE_ID = "#{MODAL_ID}_title".freeze

  def view_template
    render(Components::Modal.new(
             id: MODAL_ID,
             header: false,
             controller: "confirm-modal",
             body_class: "py-4",
             title_id: TITLE_ID
           )) do |m|
      m.with_body { render_title }
      m.with_footer { render_buttons }
    end
  end

  private

  def render_title
    h4(class: "modal-title", id: TITLE_ID,
       data: { confirm_modal_target: "title" }) do
      plain(:are_you_sure.l)
    end
  end

  def render_buttons
    button(type: "button", class: "btn btn-default",
           data: { action: "confirm-modal#cancel" }) do
      plain(:CANCEL.l)
    end
    whitespace
    button(type: "button", class: "btn btn-danger",
           data: { action: "confirm-modal#confirm",
                   confirm_modal_target: "confirmButton" }) do
      plain(:OK.l)
    end
  end
end
