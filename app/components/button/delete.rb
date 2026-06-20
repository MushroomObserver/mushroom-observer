# frozen_string_literal: true

# DELETE button with destroy-action defaults: `text-danger` appended to
# the CSS class, `action: :destroy`, `icon: :delete`, `style:
# :outline_default`, and `confirm:` defaulting to `:are_you_sure.l`.
# Caller can override any kwarg explicitly.
#
# `style: nil` suppresses ALL Bootstrap btn classes — the element
# renders as a bare glyph (still `text-danger` coloured) with no
# btn wrapper. To render as an underlined link, pass `style: :link`.
#
# @example
#   render(Components::Button::Delete.new(target: @api_key))
#
# @example with overrides
#   render(Components::Button::Delete.new(
#     target: @api_key, name: :REMOVE.l, icon: :remove
#   ))
#
# @example text-only
#   render(Components::Button::Delete.new(target: @term, icon: nil))
#
# @example bare glyph (no btn wrapper at all, not a link style)
#   render(Components::Button::Delete.new(target: alias_, style: nil))
class Components::Button::Delete < Components::Button::CRUDBase
  def initialize(target:, name: nil, **html_attrs)
    confirm = html_attrs.delete(:confirm) || :are_you_sure.l
    style   = if html_attrs.key?(:style)
                html_attrs.delete(:style)
              else
                :outline_default
              end
    icon = html_attrs.key?(:icon) ? html_attrs.delete(:icon) : :delete
    html_class = [html_attrs.delete(:class), "text-danger"].compact.join(" ")
    super(target: target,
          name: name || default_name(target),
          method: :delete,
          action: :destroy,
          style: style,
          icon: icon,
          confirm: confirm,
          class: html_class,
          **html_attrs)
  end

  private

  def default_name(target)
    if target.is_a?(String) || target.is_a?(Hash)
      :DESTROY.l
    else
      :destroy_object.t(type: target.type_tag)
    end
  end
end
