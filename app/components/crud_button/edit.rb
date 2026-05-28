# frozen_string_literal: true

class Components::CrudButton
  # GET-method `CrudButton` with the edit-action defaults baked in:
  # `action: :edit`, `icon: :edit`. Path prefixing follows the parent
  # `NAMED_ROUTE_ACTIONS` whitelist (`edit_<model>_path`).
  #
  # Used as the Phlex-side equivalent of `LinkHelper#edit_button` —
  # that ERB helper now delegates here.
  #
  # @example Phlex caller
  #   render(Components::CrudButton::Edit.new(target: @herbarium))
  #
  # @example text-only (opt out of the default icon)
  #   render(Components::CrudButton::Edit.new(target: @herbarium,
  #                                           icon: nil))
  #
  # @example icon-only inline in a table row (opt out of the btn frame)
  #   render(Components::CrudButton::Edit.new(target: alias_, btn: nil))
  class Edit < Components::CrudButton::Get
    def initialize(target:, name: nil, **args)
      # `unless args.key?(:icon)` (not `||=`) so callers can opt out of
      # the default icon by passing `icon: nil` explicitly.
      args[:icon] = :edit unless args.key?(:icon)
      # Same `key?` opt-out for the button-frame default: icon-only
      # inline edits (dense table rows, list cells) pass `btn: nil`
      # to render a bare glyph without the surrounding `btn` styling.
      args[:btn] = "btn btn-outline-default" unless args.key?(:btn)
      super(target: target,
            name: name || default_name(target),
            action: :edit,
            **args)
    end

    private

    # Mirrors `Delete#default_name`: `:EDIT.l` for path-like targets
    # (String / Hash) where the type isn't recoverable; otherwise
    # `:edit_object.t(type: …)` for the more descriptive sr-only
    # label.
    def default_name(target)
      if target.is_a?(String) || target.is_a?(Hash)
        :EDIT.l
      else
        :edit_object.t(type: target.type_tag)
      end
    end
  end
end
