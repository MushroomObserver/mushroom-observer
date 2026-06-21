# frozen_string_literal: true

# Shared button-styling logic for `Components::Button` and
# `Components::Button::CRUDBase`. Both include this concern so they expose
# identical `btn_class` / `size_class` methods without going through a
# third-party namespace.
#
# `module_function` makes `btn_class`, `size_class`, and
# `validate_no_btn_classes!` available as both private instance methods on
# any includer AND as module-level methods
# (`Components::ButtonStyling.btn_class(:primary)`). The nested
# `ClassMethods` module (auto-extended by `ActiveSupport::Concern`) exposes
# them as class methods on each includer so class-level helpers
# (e.g. `FieldHelpers#submit`) can call `klass.btn_class(style)` directly.
#
# Style symbols are kebab-cased and prefixed with `"btn-"` — `:primary`
# becomes `"btn-primary"`, `:outline_default` becomes
# `"btn-outline-default"`. The base `"btn"` class is added separately
# by each component's `merged_class` so `style: nil` renders no
# Bootstrap button framing at all.
module Components::ButtonStyling
  extend ActiveSupport::Concern

  BTN_STYLES = [
    :default, :primary, :danger, :warning, :success, :info, :link,
    :outline_default, :outline_primary, :outline_danger,
    :outline_warning, :outline_success, :outline_info
  ].freeze

  BTN_SIZES = { lg: "btn-lg", sm: "btn-sm", xs: "btn-xs" }.freeze

  BTN_DEFAULT_STYLE = :default

  module ClassMethods
    def btn_class(style) = Components::ButtonStyling.btn_class(style)
    def size_class(size) = Components::ButtonStyling.size_class(size)
  end

  module_function

  def btn_class(style)
    return nil if style.nil?

    unless BTN_STYLES.include?(style)
      raise(ArgumentError.new("Unknown style: #{style.inspect}. " \
                              "Valid: #{BTN_STYLES.join(", ")}"))
    end

    "btn-#{style.to_s.tr("_", "-")}"
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
      c == "btn" || c.start_with?("btn-")
    end
    return if offenders.empty?

    raise(ArgumentError.new(
            "Don't pass Bootstrap btn classes via class: " \
            "(found: #{offenders.join(" ")}). " \
            "Use style: and size: kwargs instead — " \
            "e.g. style: :primary, size: :sm."
          ))
  end
end
