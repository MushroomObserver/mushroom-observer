# frozen_string_literal: true

# GET button with edit-action defaults: `action: :edit`, `icon: :edit`,
# `style: :outline_default`. Caller can override any kwarg explicitly.
#
# `style: nil` suppresses ALL Bootstrap btn classes — the element
# renders as a bare glyph with no btn wrapper. To render as an
# underlined link, pass `style: :link` instead.
#
# @example
#   render(Components::Button::Edit.new(target: @herbarium))
#
# @example text-only
#   render(Components::Button::Edit.new(target: @herbarium, icon: nil))
#
# @example bare glyph (no btn wrapper at all, not a link style)
#   render(Components::Button::Edit.new(target: alias_, style: nil))
#
# @example render as an underlined link
#   render(Components::Button::Edit.new(target: alias_, style: :link))
class Components::Button::Edit < Components::Button::Get
  def initialize(target:, name: nil,
                 style: :outline_default, icon: :edit, **)
    super(target: target,
          name: name || default_name(target),
          action: :edit,
          style: style,
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
