# frozen_string_literal: true

# Bootstrap modal wrapper for forms.
# Used in turbo_stream responses from `new` and `edit` form actions.
#
# The modal listens for section-update:updated events to auto-close when
# the page section is successfully updated. The user_id comparison ensures
# broadcasts don't unintentionally close other users' modals.
#
# If form submit fails, the flash and form are updated via turbo-stream
# targeting modal_{identifier}_flash and {identifier}_form.
#
class Components::ModalForm < Components::Base
  include Phlex::Slotable

  prop :identifier, String
  prop :title, String
  prop :user, User

  slot :form_content

  def view_template
    div(**modal_attributes) do
      div(class: "modal-dialog modal-lg", role: "document") do
        div(class: "modal-content") do
          render_header
          render_body
        end
      end
    end
  end

  private

  def modal_attributes
    {
      class: "modal",
      id: "modal_#{@identifier}",
      role: "dialog",
      aria: { labelledby: "modal_#{@identifier}_header" },
      data: modal_data
    }
  end

  def modal_data
    {
      controller: "modal",
      modal_user_value: @user.id,
      action: "section-update:updated@window->modal#remove",
      identifier: @identifier
    }
  end

  def render_header
    div(class: "modal-header") do
      close_button
      h4(class: "modal-title", id: "modal_#{@identifier}_header") { @title }
    end
  end

  def close_button
    button(
      type: :button,
      class: "close",
      data: { dismiss: "modal" },
      aria: { label: :CLOSE.l }
    ) do
      span(aria: { hidden: "true" }) { "×" }
    end
  end

  def render_body
    div(class: "modal-body", id: "modal_#{@identifier}_body") do
      div(id: "modal_#{@identifier}_flash")
      render(form_content_slot) if form_content_slot?
    end
  end
end
