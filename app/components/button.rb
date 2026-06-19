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
#     btn: "btn btn-danger",
#     data: { action: "confirm-modal#confirm",
#             confirm_modal_target: "confirmButton" }
#   ))
#
# @example Icon-only (sr-only label)
#   render(Components::Button.new(
#     name: :REMOVE.l,
#     icon: :x,
#     btn: nil,
#     class: "btn btn-link text-danger p-0"
#   ))
#
class Components::Button < Components::Base
  DEFAULT_BTN = "btn btn-default"

  def initialize(name:, btn: DEFAULT_BTN, icon: nil, icon_class: nil,
                 **html_attrs)
    super()
    @name = name
    @btn = btn
    @icon = icon
    @icon_class = icon_class
    @html_attrs = html_attrs
  end

  def view_template
    button(type: :button, class: merged_class, **extra_attrs) do
      button_content
    end
  end

  private

  def merged_class
    class_names(@btn, @html_attrs[:class])
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
