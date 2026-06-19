# frozen_string_literal: true

class Components::CrudButton
  # DELETE-method `CrudButton` with the destroy-action defaults
  # baked in: appends `text-danger` to the button class, defaults
  # `name:` to a localized "Destroy X" / `:DESTROY.l`, and defaults
  # `confirm:` to `:are_you_sure.l`. Caller can override any of
  # those by passing the kwarg explicitly.
  #
  # @example Phlex caller
  #   render(Components::CrudButton::Delete.new(target: @api_key))
  #
  # @example with overrides
  #   render(Components::CrudButton::Delete.new(
  #     target: @api_key, name: :REMOVE.l, icon: :remove
  #   ))
  #
  # @example text-only (opt out of the default icon)
  #   render(Components::CrudButton::Delete.new(target: @term, icon: nil))
  #
  # @example icon-only inline in a table row (opt out of the btn frame)
  #   render(Components::CrudButton::Delete.new(target: alias_, btn: nil))
  class Delete < Components::CrudButton
    def initialize(target:, name: nil, **args)
      args[:class] = [args[:class], "text-danger"].compact.join(" ").strip
      args[:confirm] ||= :are_you_sure.l
      # `unless args.key?(:icon)` (not `||=`) so callers can opt out of
      # the default icon by passing `icon: nil` explicitly — text-only
      # destroy buttons (e.g. context-nav `[ DESTROY ]` tabs).
      args[:icon] = :delete unless args.key?(:icon)
      # Same `key?` opt-out for the button-frame default: icon-only
      # inline destroys (dense table rows, list cells) pass `btn: nil`
      # to render a bare glyph without the surrounding `btn` styling.
      args[:btn] = "btn btn-outline-default" unless args.key?(:btn)
      super(
        target: target,
        name: name || default_name(target),
        method: :delete,
        action: :destroy,
        **args
      )
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
end
