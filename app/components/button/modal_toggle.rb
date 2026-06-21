# frozen_string_literal: true

# Modal-trigger link (`<a>`) that opens a Bootstrap modal via the
# `modal-toggle` Stimulus controller. Inherits full button-styling
# support from `Components::Button::Get`.
#
# The Stimulus controller fetches the modal body from `target` as a
# turbo-stream response and shows the modal. If a modal is already
# open under the same `modal_id`, it reuses the element.
#
# Defaults to the standard btn frame (`btn btn-default`) — no variant:
# needed for the common case. Pass `variant: :strip` for a plain text
# link or icon-only trigger (e.g. `variant: :strip, icon: :edit`).
#
# @example Button-shaped modal trigger (the common case)
#   render(Components::Button::ModalToggle.new(
#     name: :show_project_trust_settings.l,
#     target: trust_modal_project_member_path(...),
#     modal_id: "trust_settings",
#     size: :lg, class: "my-2 mr-2"
#   ))
#
# @example Plain text modal link
#   render(Components::Button::ModalToggle.new(
#     name: "Edit", target: edit_comment_path(comment),
#     modal_id: "comment", variant: :strip
#   ))
#
# @example Icon-only modal trigger (tooltip from name:)
#   render(Components::Button::ModalToggle.new(
#     name: :show_comments_add_comment.l,
#     target: new_comment_path(target: obj.id, type: obj.class.name),
#     modal_id: "comment",
#     variant: :strip, icon: :add
#   ))
class Components::Button::ModalToggle < Components::Button::Get
  def initialize(name:, target:, modal_id:, **)
    super(name: name, target: target, **)
    @modal_id = modal_id
  end

  private

  def link_html_options
    super.deep_merge(data: modal_data)
  end

  def modal_data
    {
      modal: "modal_#{@modal_id}",
      controller: "modal-toggle",
      action: "modal-toggle#showModal:prevent"
    }
  end
end
