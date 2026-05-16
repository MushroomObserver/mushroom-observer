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
  # FormCarouselItem only manages the visual `.active` class on the
  # label.
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
  #     label_class: "btn btn-default thumb_img_btn",
  #     label_data: { action: "click->form-images#setObsThumbnail" }
  #   )) do
  #     span(class: "set_thumb_img_text") { :image_set_default.l }
  #   end
  class ButtonStyleRadio < Phlex::HTML
    include Components::TrustedHtml

    # @param name [String] HTML name (shared across radios in the group)
    # @param value [String] value submitted when this radio is checked
    # @param id [String] HTML id (matches the label's `for`)
    # @param checked [Boolean] initial checked state
    # @param label [Hash] HTML attrs for the `<label>` wrap
    #   (e.g. `class:`, `data:`)
    # @param input_attrs [Hash] HTML attrs passed through to the
    #   `<input>` (e.g. `class:`, `data:`)
    # rubocop:disable Metrics/ParameterLists
    def initialize(name:, value:, id:, checked: false,
                   label: {}, **input_attrs)
      # rubocop:enable Metrics/ParameterLists
      super()
      @name = name
      @value = value
      @id = id
      @checked = checked
      @label_attrs = label
      @input_attrs = input_attrs
    end

    def view_template(&block)
      label(for: @id, **@label_attrs) do
        input(**input_attributes)
        yield if block
      end
    end

    private

    def input_attributes
      { type: :radio, name: @name, id: @id, value: @value,
        checked: @checked, **@input_attrs }
    end
  end
end
