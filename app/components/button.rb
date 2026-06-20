# frozen_string_literal: true

# Renders a standalone `<button type="button">` — for Stimulus-driven
# actions, modal triggers, and any interactive element that does NOT
# submit a form. For server mutations (POST/PATCH/PUT/DELETE) that need
# CSRF protection, use `Components::Button::CRUDBase` instead.
#
# Button styling is shared with `Components::Button::CRUDBase` via the
# `Components::ButtonStyling` concern.
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
  include Components::ButtonStyling

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
    validate_no_btn_classes!(@html_attrs[:class])
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
    class_names(("btn" if @style),
                btn_class(@style),
                size_class(@size),
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
