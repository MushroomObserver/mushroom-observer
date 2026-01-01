# frozen_string_literal: true

# Bootstrap modal with spinner for progress indicator (e.g., "saving vote").
# Cannot be dismissed by user - must be hidden programmatically by JS.
#
# Usage: Rendered once in the application layout.
#   render(Components::ModalProgressSpinner.new)
#
class Components::ModalProgressSpinner < Components::Base
  def view_template
    div(id: "mo_ajax_progress", class: "modal", role: "dialog",
        aria: { labelledby: "mo_ajax_progress_caption" },
        data: modal_data) do
      div(class: "modal-dialog modal-sm", role: "document") do
        div(class: "modal-content") do
          modal_body
        end
      end
    end
  end

  private

  def modal_data
    {
      controller: "modal",
      action: "section-update:updated@window->modal#hide",
      keyboard: "false",
      backdrop: "static"
    }
  end

  def modal_body
    div(id: "modal_ajax_progress_body", class: "modal-body text-center") do
      span(id: "mo_ajax_progress_caption")
      spinner
    end
  end

  def spinner
    span(class: "spinner-right mx-2")
  end
end
