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
#     variant: :danger,
#     data: { action: "confirm-modal#confirm",
#             confirm_modal_target: "confirmButton" }
#   ))
#
# @example Icon-only (sr-only label)
#   render(Components::Button.new(name: :REMOVE.l, icon: :x, variant: :strip))
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

  ALLOWED_TAGS = [:button, :a, :span, :label].freeze

  # Single dispatch table mapping type: → subclass constant name.
  # Every Button shape is identified by a single `type:` kwarg.
  # The kwarg is stripped before the subclass call so subclasses
  # don't need to declare it.
  DISPATCH = {
    # HTTP-method buttons
    post: :Post, put: :Put, patch: :Patch,
    delete: :Delete, get: :Get,
    # Semantic GET shortcuts (icon + action presets)
    edit: :Edit, new: :New, download: :Download, project: :Project,
    # Behavioral subclasses
    submit: :Submit, external: :External,
    modal: :ModalToggle, toggle: :Toggle
  }.freeze

  # Single-entry-point dispatcher. Pass `type:` to route to the
  # matching subclass. Omit for a plain `<button type="button">`.
  #
  #   Components::Button.new(type: :post,     name: "Join",   target: url)
  #   Components::Button.new(type: :put,      name: "Save",   target: url)
  #   Components::Button.new(type: :patch,    name: "Update", target: url)
  #   Components::Button.new(type: :delete,   target: @obj)
  #   Components::Button.new(type: :get,      name: "Show",   target: url)
  #   Components::Button.new(type: :edit,     target: @herbarium)
  #   Components::Button.new(type: :new,      target: path,
  #                          name: :new_object.t(type: :herbarium))
  #   Components::Button.new(type: :download, target: path)
  #   Components::Button.new(type: :project,  name: ..., target: ...)
  #   Components::Button.new(type: :submit,   name: "Go")
  #   Components::Button.new(type: :external, url: url, name: "BLAST")
  #   Components::Button.new(type: :modal,    name: "Settings",
  #                          target: path, modal_id: "trust_settings")
  #   Components::Button.new(type: :toggle,   show_text: "Open",
  #                          hide_text: "Close", show_class: "map-show",
  #                          hide_class: "map-hide")
  #   Components::Button.new(name: "Cancel", data: { dismiss: "modal" })
  def self.new(**kwargs, &block)
    type_sym = kwargs[:type]&.to_sym
    if (klass_name = DISPATCH[type_sym])
      kwargs.delete(:type)
      return const_get(klass_name).new(**kwargs, &block)
    end

    super
  end

  include Components::ButtonContent

  def initialize(name: nil, variant: nil, size: nil, icon: nil, **html_attrs)
    super()
    @name = name
    @variant = variant
    @size = size
    @tag = html_attrs.delete(:tag) || :button
    @type = html_attrs.delete(:type) || :button
    @icon = icon
    @icon_class = html_attrs.delete(:icon_class)
    @label = html_attrs.delete(:label)
    onclick = html_attrs.delete(:onclick)
    @html_attrs = html_attrs
    # Phlex blocks `onclick` by name; wrap in SafeValue to opt in.
    @html_attrs[:onclick] = Phlex::SGML::SafeValue.new(onclick) if onclick
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

  def btn_styling
    return nil if @variant == :strip

    class_names("btn", btn_class(@variant))
  end

  def merged_class
    class_names(btn_styling, size_class(@size), @html_attrs[:class])
  end

  def extra_attrs
    @html_attrs.except(:class)
  end
end
