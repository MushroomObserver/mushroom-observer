# frozen_string_literal: true

# GET button with edit-action defaults: `action: :edit`, `icon: :edit`.
# Defaults to the standard btn frame. Pass `variant: :strip` for a bare
# edit icon, `variant: :outline` for the outline style, or any other
# variant explicitly.
#
# @example default (standard btn-default frame with edit icon)
#   render(Components::Button.new(type: :edit, target: @herbarium))
#
# @example outline button (common CRUD row usage)
#   render(Components::Button.new(type: :edit, target: @herbarium,
#                                 variant: :outline))
#
# @example bare icon, no btn frame
#   render(Components::Button.new(type: :edit, target: @herbarium,
#                                 variant: :strip))
#
# @example text-only, no btn frame
#   render(Components::Button.new(type: :edit, target: @herbarium,
#                                 icon: nil))
#
# @example rendered as an underlined link
#   render(Components::Button.new(type: :edit, target: alias_,
#                                 variant: :btn_link))
class Components::Button::Edit < Components::Button::Get
  def initialize(target:, name: nil, icon: :edit, **)
    super(target: target,
          name: name || default_name(target),
          action: :edit,
          icon: icon,
          **)
  end

  private

  def default_name(target)
    if target.is_a?(String) || target.is_a?(Hash)
      :EDIT.l
    else
      :edit_object.t(type: target.type_tag)
    end
  end
end
