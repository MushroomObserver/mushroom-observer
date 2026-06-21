# frozen_string_literal: true

# Renders a styled button or button-like element. The default tag is
# `<button type="button">` (Stimulus actions, modal triggers). Pass
# `tag: :a` for link-shaped buttons, or `tag: :span` for non-interactive
# btn-group members (disabled pills, active-state pills). For server
# mutations needing CSRF, use `Components::Button::CRUDBase`. For form
# submits, use `Components::Button::Submit`.
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
#   render(Components::Button.new(name: :REMOVE.l, icon: :x, style: nil))
#
# @example Rich content via block (name: optional)
#   render(Components::Button.new(
#     data: { action: "form-exif#transfer:prevent" }
#   )) do
#     span(class: "when-enabled") { :ENABLED.l }
#     span(class: "when-disabled") { :DISABLED.l }
#   end
#
class Components::Button < Components::Base
  include Components::ButtonStyling

  ALLOWED_TAGS = [:button, :a, :span].freeze

  def initialize(name: nil, style: BTN_DEFAULT_STYLE, size: nil, icon: nil,
                 **html_attrs)
    super()
    @name = name
    @style = style
    @size = size
    @tag = html_attrs.delete(:tag) || :button
    @type = html_attrs.delete(:type) || :button
    @icon = icon
    @icon_class = html_attrs.delete(:icon_class)
    @html_attrs = html_attrs
    validate_no_btn_classes!(@html_attrs[:class])
  end

  def view_template(&block)
    raise(ArgumentError.new("tag must be one of #{ALLOWED_TAGS}")) unless
      ALLOWED_TAGS.include?(@tag)

    attrs = { class: merged_class, **extra_attrs }
    attrs[:type] = @type if @tag == :button
    send(@tag, **attrs) { block ? yield : button_content }
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
      span(class: "sr-only") { trusted_html(@name) } if @name
      render(Components::Icon.new(type: @icon, html_class: @icon_class))
    elsif @name
      trusted_html(@name)
    end
  end
end
