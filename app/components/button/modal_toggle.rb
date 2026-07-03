# frozen_string_literal: true

# Modal-trigger link (`<a>`) that opens a Bootstrap modal via the
# `modal-toggle` Stimulus controller. Inherits all rendering from
# `Components::Link::Modal`; adds button styling so the default output
# is a `btn btn-default` anchor rather than a plain link.
#
# Pass `variant: :strip` for a plain text link or icon-only trigger.
#
# @example Button-shaped modal trigger (the common case)
#   Button(type: :modal,
#     name: :show_project_trust_settings.l,
#     target: trust_modal_project_member_path(...),
#     modal_id: "trust_settings",
#     size: :lg, class: "my-2 mr-2"
#   )
#
# @example Plain text modal link
#   Button(type: :modal,
#     name: "Edit", target: edit_comment_path(comment),
#     modal_id: "comment", variant: :strip
#   )
#
# @example Icon-only modal trigger (tooltip from name:)
#   Button(type: :modal,
#     name: :show_comments_add_comment.l,
#     target: new_comment_path(target: obj.id, type: obj.class.name),
#     modal_id: "comment",
#     variant: :strip, icon: :add
#   )
class Components::Button::ModalToggle < Components::Link::Modal
  def initialize(name:, target:, modal_id:, variant: nil, **)
    super(modal_id: modal_id, name: name, target: target, button: variant, **)
  end

  private

  def btn_styling
    return nil if @button == :strip

    class_names("btn", btn_class(@button))
  end
end
