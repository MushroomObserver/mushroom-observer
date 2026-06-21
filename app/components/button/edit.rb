# frozen_string_literal: true

# GET button with edit-action defaults: `action: :edit`, `icon: :edit`,
# `variant: :strip` (no btn frame). Pass `variant: :outline` for the
# standard outline button, or any other variant explicitly.
#
# @example default (bare edit icon)
#   render(Components::Button::Edit.new(target: @herbarium))
#
# @example outline button (common CRUD row usage)
#   render(Components::Button::Edit.new(target: @herbarium, variant: :outline))
#
# @example text-only, no btn frame
#   render(Components::Button::Edit.new(target: @herbarium, icon: nil))
#
# @example rendered as an underlined link
#   render(Components::Button::Edit.new(target: alias_, variant: :btn_link))
class Components::Button::Edit < Components::Button::Get
  def initialize(target:, name: nil, variant: :strip, icon: :edit, **)
    super(target: target,
          name: name || default_name(target),
          action: :edit,
          variant: variant,
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
