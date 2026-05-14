# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap radio button group component.
  #
  # Each option renders as:
  #   <div class="radio">
  #     <label><input type="radio" ...> label text</label>
  #   </div>
  #
  # Delegates per-option markup generation to
  # `Superform::Rails::Components::Radios`, using its block form so we can
  # wrap each option in the Bootstrap `.radio` div and emit HTML-safe label
  # text via `trusted_html`. The component works equally with a Superform
  # field or a `FieldProxy` (standalone use outside a form).
  #
  # @example Superform field
  #   field(:target).radio(
  #     [1, "Option 1"], [2, "Option 2"],
  #     wrapper_options: { wrap_class: "mt-3" }
  #   )
  #
  # @example Standalone with FieldProxy
  #   proxy = FieldProxy.new("chosen_name", :name_id)
  #   RadioField.new(proxy, [1, "Opt 1"], [2, "Opt 2"])
  class RadioField < Phlex::HTML
    include Components::TrustedHtml

    attr_reader :wrapper_options, :field, :attributes

    def initialize(field, *collection, wrapper_options: {}, **attributes)
      super()
      @field = field
      @collection = collection
      @attributes = attributes
      @wrapper_options = wrapper_options
    end

    def view_template
      render(radios_component) do |choice|
        render_choice(choice)
      end
    end

    private

    def radios_component
      Superform::Rails::Components::Radios.new(
        @field, options: @collection, **@attributes
      )
    end

    def render_choice(choice)
      value_str = choice.value.to_s
      div(class: radio_class) do
        label do
          # Stringify value so Phlex doesn't dasherize symbols
          # (e.g. `:mycoportal_image_list` → `"mycoportal-image-list"`).
          # Use a value-derived index so the rendered id is value-based
          # (`field_id_<value>`), matching MO's pre-upstream convention
          # used by JS/CSS, rather than upstream's default index-based id.
          # `checked` is computed here because upstream Radio's
          # `field.value == @value` doesn't coerce types — MO routinely
          # pairs boolean/symbol field values with string option values.
          render(Superform::Rails::Components::Radio.new(
                   @field,
                   value: value_str,
                   index: index_for(value_str),
                   checked: option_checked?(value_str),
                   **@attributes
                 ))
          whitespace
          trusted_html(choice.text)
        end
      end
    end

    def index_for(value_str)
      value_str.parameterize(separator: "_")
    end

    def option_checked?(value_str)
      @field.value.to_s == value_str
    end

    def radio_class
      classes = "radio"
      if wrapper_options[:wrap_class].present?
        classes += " #{wrapper_options[:wrap_class]}"
      end
      classes
    end
  end
end
