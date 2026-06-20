# frozen_string_literal: true

# Shared button-styling logic for `Components::Button` and
# `Components::Button::CRUDBase`. Both include this concern so they expose
# identical `btn_class` / `size_class` methods without going through a
# third-party namespace.
#
# `btn_class` and `size_class` are private instance methods — any includer
# can call them directly inside its own methods without going through
# `self.class`. They are also promoted to class methods (via
# `class_methods do`) so class-level helpers (e.g. `FieldHelpers#submit`)
# can call `Components::ButtonStyling.btn_class(style)` directly.
#
# Style symbols are kebab-cased and prefixed with `"btn-"` — `:primary`
# becomes `"btn-primary"`, `:outline_default` becomes
# `"btn-outline-default"`. The base `"btn"` class is added separately
# by each component's `merged_class` so `style: nil` renders no
# Bootstrap button framing at all.
module Components::ButtonStyling
  extend ActiveSupport::Concern

  PERMITTED_STYLES = [
    :default, :primary, :danger, :warning, :success, :info, :link,
    :outline_default, :outline_primary, :outline_danger,
    :outline_warning, :outline_success, :outline_info
  ].freeze

  BTN_SIZES = { lg: "btn-lg", sm: "btn-sm", xs: "btn-xs" }.freeze

  DEFAULT_STYLE = :default

  private

  def btn_class(style)
    return nil if style.nil?

    unless PERMITTED_STYLES.include?(style)
      raise(ArgumentError.new("Unknown style: #{style.inspect}. " \
                              "Valid: #{PERMITTED_STYLES.join(", ")}"))
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

  class_methods do
    def btn_class(style)
      return nil if style.nil?

      unless PERMITTED_STYLES.include?(style)
        raise(ArgumentError.new("Unknown style: #{style.inspect}. " \
                                "Valid: #{PERMITTED_STYLES.join(", ")}"))
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
  end
end
