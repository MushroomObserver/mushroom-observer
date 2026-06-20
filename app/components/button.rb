# frozen_string_literal: true

# Renders a standalone `<button type="button">` — for Stimulus-driven
# actions, modal triggers, and any interactive element that does NOT
# submit a form. For server mutations (POST/PATCH/PUT/DELETE) that need
# CSRF protection, use `Components::CrudButton` instead.
#
# Default styling (`btn btn-default`) is owned here and referenced by
# `Components::CrudButton` subclasses so both kinds of button share the
# same visual baseline without coupling their implementations.
#
# @example Stimulus action button
#   render(Components::Button.new(
#     name: :CANCEL.l,
#     data: { action: "confirm-modal#cancel" }
#   ))
#
# @example Danger variant
#   render(Components::Button.new(
#     name: :OK.l,
#     style: :danger,
#     data: { action: "confirm-modal#confirm",
#             confirm_modal_target: "confirmButton" }
#   ))
#
# @example Icon-only (sr-only label)
#   render(Components::Button.new(
#     name: :REMOVE.l,
#     icon: :x,
#     style: nil,
#     class: "btn btn-link text-danger p-0"
#   ))
#
class Components::Button < Components::Base
  BTN_STYLES = {
    default: "btn btn-default",
    primary: "btn btn-primary",
    danger: "btn btn-danger",
    warning: "btn btn-warning",
    success: "btn btn-success",
    info: "btn btn-info",
    link: "btn btn-link",
    outline_default: "btn btn-outline-default",
    outline_primary: "btn btn-outline-primary",
    outline_danger: "btn btn-outline-danger",
    outline_warning: "btn btn-outline-warning",
    outline_success: "btn btn-outline-success",
    outline_info: "btn btn-outline-info"
  }.freeze

  BTN_SIZES = {
    lg: "btn-lg",
    sm: "btn-sm",
    xs: "btn-xs"
  }.freeze

  DEFAULT_STYLE = :default

  def self.btn_class(variant)
    return nil if variant.nil?

    BTN_STYLES.fetch(variant) do
      raise(ArgumentError.new("Unknown style: #{variant.inspect}. " \
                           "Valid: #{BTN_STYLES.keys.join(", ")}"))
    end
  end

  def self.size_class(size)
    return nil if size.nil?

    BTN_SIZES.fetch(size) do
      raise(ArgumentError.new("Unknown size: #{size.inspect}. " \
                           "Valid: #{BTN_SIZES.keys.join(", ")}"))
    end
  end

  def initialize(name:, style: DEFAULT_STYLE, size: nil, icon: nil,
                 **html_attrs)
    super()
    @name = name
    @style = style
    @size = size
    @tag = html_attrs.delete(:tag) || :button
    @icon = icon
    @icon_class = html_attrs.delete(:icon_class)
    @html_attrs = html_attrs
  end

  def view_template
    if @tag == :a
      a(class: merged_class, **extra_attrs) { button_content }
    else
      button(type: :button, class: merged_class, **extra_attrs) do
        button_content
      end
    end
  end

  private

  def merged_class
    class_names(self.class.btn_class(@style),
                self.class.size_class(@size),
                @html_attrs[:class])
  end

  def extra_attrs
    @html_attrs.except(:class)
  end

  def button_content
    if @icon
      span(class: "sr-only") { trusted_html(@name) }
      render(Components::Icon.new(type: @icon, html_class: @icon_class))
    else
      trusted_html(@name)
    end
  end
end
