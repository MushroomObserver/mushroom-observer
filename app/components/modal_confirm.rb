# frozen_string_literal: true

# Bootstrap modal for Turbo confirmation dialogs.
# Replaces the browser's native confirm() with a styled modal.
# Used by Turbo.config.forms.confirm via the confirm-modal Stimulus controller.
#
# Usage: Rendered once in the application layout.
#   render(Components::ModalConfirm.new)
#
class Components::ModalConfirm < Components::Base
  def view_template
    div(id: "mo_confirm", class: "modal", role: "dialog",
        aria: { labelledby: "mo_confirm_title" },
        data: { controller: "confirm-modal" }) do
      div(class: "modal-dialog", role: "document") do
        div(class: "modal-content") do
          modal_body
          modal_footer
        end
      end
    end
  end

  private

  def modal_body
    div(class: "modal-body py-4") do
      h4(class: "modal-title", id: "mo_confirm_title",
         data: { confirm_modal_target: "title" }) do
        plain(:are_you_sure.l)
      end
    end
  end

  def modal_footer
    div(class: "modal-footer") do
      cancel_button
      whitespace
      confirm_button
    end
  end

  def cancel_button
    button(type: "button", class: "btn btn-default",
           data: { action: "confirm-modal#cancel" }) do
      plain(:CANCEL.l)
    end
  end

  def confirm_button
    button(type: "button", class: "btn btn-danger",
           data: { action: "confirm-modal#confirm",
                   confirm_modal_target: "confirmButton" }) do
      plain(:OK.l)
    end
  end
end
