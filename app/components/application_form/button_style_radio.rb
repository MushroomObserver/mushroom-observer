# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap 3 button-styled radio: a `<label class="btn …">` wrapping
  # an `<input type="radio">` plus arbitrary block content (the visible
  # text/icons). NO `.radio` div wrap — that wrap is for vertical
  # checkbox-list layout; this component is for radios that look and
  # behave like buttons (BS3's `.btn-group[data-toggle="buttons"]`
  # pattern, or standalone button-styled radios scattered across a
  # form).
  #
  # Multiple instances with the same `name:` form a radio group via
  # browser-native behavior — no JS needed to manage checked state
  # across them. The `data-form-images-target`-style hook in
  # Form::UploadGallery::Item only manages the visual `.active` class on
  # the label.
  #
  # Standalone (no Superform context) — takes raw HTML kwargs rather
  # than a `Field` / `FieldProxy`, since the call sites (carousel
  # cards, in-form toolbar radios) don't always have a form context
  # available and the radio name is usually fixed by the surrounding
  # markup contract anyway.
  #
  # @example
  #   render(Components::ApplicationForm::ButtonStyleRadio.new(
  #     name: "observation[thumb_image_id]", value: image.id,
  #     id: "thumb_image_id_#{image.id}", checked: thumb?,
  #     size: :sm, label: { class: "thumb_img_btn" }
  #   )) do
  #     span(class: "set_thumb_img_text") { :image_set_default.l }
  #   end
  class ButtonStyleRadio < Phlex::HTML
    # Extends `Phlex::HTML` directly (not `Components::Base`), so it
    # gets no Kit sugar on its own — see `.claude/rules/phlex_reference.md`'s
    # "Kit sugar doesn't reach app/components/application_form/*" section.
    include ::Components

    # @param name [String] HTML name (shared across radios in the group)
    # @param value [String] value submitted when this radio is checked
    # @param id [String] HTML id (matches the label's `for`)
    # @param checked [Boolean] initial checked state
    # @param variant [Symbol, nil] btn variant; nil (default) for btn-default
    #   frame, :strip for a plain label with no btn classes
    # @param size [Symbol, nil] btn size modifier (`:sm`, `:lg`, etc.)
    # @param label [Hash] extra HTML attrs for the `<label>` (e.g.
    #   `class:` for identifier classes, `data:`). Do not pass btn classes
    #   here — use `variant:` and `size:` instead.
    # @param input_attrs [Hash] HTML attrs passed through to `<input>`
    def initialize(name:, value:, id:, **opts)
      super()
      @name = name
      @value = value
      @id = id
      @checked = opts.delete(:checked) { false }
      @variant = opts.delete(:variant)
      @size = opts.delete(:size)
      @label_attrs = opts.delete(:label) || {}
      @input_attrs = opts
    end

    def view_template(&block)
      Button(tag: :label, for: @id, variant: @variant, size: @size,
             class: @label_attrs[:class],
             **@label_attrs.except(:class)) do
        input(**input_attributes)
        block&.call
      end
    end

    private

    def input_attributes
      { type: :radio, name: @name, id: @id, value: @value,
        checked: @checked, **@input_attrs }
    end
  end
end
