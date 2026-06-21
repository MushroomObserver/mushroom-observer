# frozen_string_literal: true

# DELETE button with destroy-action defaults: `text-danger` appended to
# the CSS class, `action: :destroy`, `icon: :delete`, `variant: :strip`
# (no btn frame), and `confirm:` defaulting to `:are_you_sure.l`.
# Pass `variant: :outline` for the standard outline button.
#
# @example default (bare danger icon)
#   render(Components::Button::Delete.new(target: @api_key))
#
# @example outline button (common CRUD row usage)
#   render(Components::Button::Delete.new(target: @api_key, variant: :outline))
#
# @example with overrides
#   render(Components::Button::Delete.new(
#     target: @api_key, name: :REMOVE.l, icon: :remove
#   ))
#
# @example text-only, no btn frame
#   render(Components::Button::Delete.new(target: @term, icon: nil))
class Components::Button::Delete < Components::Button::CRUDBase
  def initialize(target:, name: nil, variant: :strip, icon: :delete,
                 **html_attrs)
    confirm = html_attrs.delete(:confirm) || :are_you_sure.l
    html_class = [html_attrs.delete(:class), "text-danger"].compact.join(" ")
    super(target: target,
          name: name || default_name(target),
          method: :delete,
          action: :destroy,
          variant: variant,
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
