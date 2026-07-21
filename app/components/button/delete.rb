# frozen_string_literal: true

# DELETE button with destroy-action defaults: `text-danger` appended to
# the CSS class, `action: :destroy`, `icon: :delete`, and `confirm:`
# defaulting to `:are_you_sure.l`. Defaults to the standard btn frame.
# Pass `variant: :strip` for a bare icon, `variant: :outline` for the
# outline style.
#
# @example default (standard btn-default frame with danger icon)
#   Button(type: :delete, target: @api_key)
#
# @example outline button (common CRUD row usage)
#   Button(type: :delete, target: @api_key,
#                                 variant: :outline)
#
# @example with overrides
#   Button(type: :delete, target: @api_key,
#                                 name: :remove.ti, icon: :remove)
#
# @example bare icon, no btn frame
#   Button(type: :delete, target: @term,
#                                 variant: :strip)
class Components::Button::Delete < Components::Button::CRUDBase
  def initialize(target:, name: nil, icon: :delete, **html_attrs)
    confirm = html_attrs.delete(:confirm) || :are_you_sure.l
    html_class = [html_attrs.delete(:class), "text-danger"].compact.join(" ")
    super(target: target,
          name: name || default_name(target),
          method: :delete,
          action: :destroy,
          icon: icon,
          confirm: confirm,
          class: html_class,
          **html_attrs)
  end

  private

  def default_name(target)
    if target.is_a?(String) || target.is_a?(Hash)
      :destroy.ti
    else
      :destroy_object.t(type: target.type_tag)
    end
  end
end
