# frozen_string_literal: true

# Modal-trigger link (`<a>`) that opens a Bootstrap modal via the
# `modal-toggle` Stimulus controller. Renders as `btn btn-default`
# by default; pass `variant: :strip` for a plain text link.
#
# @example Button-shaped modal trigger (the common case)
#   render(Components::Button.new(type: :modal,
#     name: :show_project_trust_settings.l,
#     target: trust_modal_project_member_path(...),
#     modal_id: "trust_settings"
#   ))
#
# @example Plain text modal link
#   render(Components::Button.new(type: :modal,
#     name: "Edit", target: edit_comment_path(comment),
#     modal_id: "comment", variant: :strip
#   ))
class Components::Button::ModalToggle < Components::Base
  include Components::ButtonStyling

  def initialize(name:, target:, modal_id:, variant: nil, **)
    @name     = name
    @path     = target
    @modal_id = modal_id
    @button   = variant
    super()
  end

  def view_template
    link_to(@name, @path, class: merged_class, data: modal_data)
  end

  private

  def btn_styling
    return nil if @button == :strip

    class_names("btn", btn_class(@button))
  end

  def merged_class
    btn_styling
  end

  def modal_data
    {
      modal: "modal_#{@modal_id}",
      controller: "modal-toggle",
      action: "modal-toggle#showModal:prevent"
    }
  end
end
