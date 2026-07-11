# frozen_string_literal: true

# Shared button-styling logic for `Components::Button` and
# `Components::Button::CRUDBase`. Both include this concern so they expose
# identical `btn_class` / `size_class` methods without going through a
# third-party namespace.
#
# `module_function` makes `btn_class`, `size_class`, and
# `validate_no_btn_classes!` available as both private instance methods on
# any includer AND as module-level methods
# (`Components::Button::Styling.btn_class(:primary)`). The nested
# `ClassMethods` module (auto-extended by `ActiveSupport::Concern`) exposes
# them as class methods on each includer so class-level helpers
# (e.g. `FieldHelpers#submit`) can call `klass.btn_class(variant)` directly.
#
# `BTN_VARIANTS` maps variant symbols to their Bootstrap CSS class. The base
# `"btn"` class is added separately by each component's `merged_class`, so
# `variant: :strip` renders no Bootstrap button framing at all. Omit
# `variant:` (or pass `nil`) for the standard grey button (`btn btn-default`).
# `:default` is also accepted as an explicit synonym for nil/omitted —
# `Components::Link`/`Link::Icon` need to distinguish "no button framing
# at all" (nil, a plain link) from "framed as the default button"
# (`:default`, a different state at that layer), so `btn_class` treats
# both the same rather than making every such caller translate `:default`
# to `nil` itself.
module Components::Button::Styling
  extend ActiveSupport::Concern

  BTN_VARIANTS = {
    primary: "btn-primary",
    danger: "btn-danger",
    warning: "btn-warning",
    success: "btn-success",
    info: "btn-info",
    btn_link: "btn-link",
    outline: "btn-outline-default",
    outline_primary: "btn-outline-primary",
    outline_danger: "btn-outline-danger",
    outline_warning: "btn-outline-warning",
    outline_success: "btn-outline-success",
    outline_info: "btn-outline-info"
  }.freeze

  BTN_SIZES = { lg: "btn-lg", sm: "btn-sm", xs: "btn-xs" }.freeze

  module ClassMethods
    def btn_class(variant) = Components::Button::Styling.btn_class(variant)
    def size_class(size) = Components::Button::Styling.size_class(size)
  end

  module_function

  def btn_class(variant)
    variant = nil if variant == :default
    return "btn-default" if variant.nil?
    return nil if variant == :strip

    css = BTN_VARIANTS[variant]
    if css.nil?
      raise(ArgumentError.new("Unknown variant: #{variant.inspect}. " \
                              "Valid: #{BTN_VARIANTS.keys.join(", ")}, " \
                              "or :strip for no btn frame. " \
                              "Omit variant: for the default grey button."))
    end

    css
  end

  def size_class(size)
    return nil if size.nil?

    BTN_SIZES.fetch(size) do
      raise(ArgumentError.new("Unknown size: #{size.inspect}. " \
                              "Valid: #{BTN_SIZES.keys.join(", ")}"))
    end
  end

  def validate_no_btn_classes!(html_class)
    return if html_class.blank?

    offenders = html_class.split.select do |c|
      c.start_with?("btn-") || c == "btn"
    end
    return if offenders.empty?

    raise(ArgumentError.new(
            "Pass btn classes via variant:/size: kwargs, not class:. " \
            "Offending class(es): #{offenders.join(", ")}"
          ))
  end
end
