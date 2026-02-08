# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap radio button group component with radio wrapper per option
  #
  # Renders each option as:
  #   <div class="radio">
  #     <label><input type="radio" ...> label text</label>
  #   </div>
  #
  # Accepts a Superform field or a FieldProxy for standalone use.
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

    def initialize(field, *collection, attributes: {},
                   wrapper_options: {})
      super()
      @field = field
      @collection = collection
      @attributes = attributes
      @wrapper_options = wrapper_options
    end

    def view_template
      map_options(@collection).each do |value, label_text|
        render_radio_option(value, label_text)
      end
    end

    private

    def render_radio_option(value, label_text)
      div(class: radio_class) do
        label do
          input(**radio_attributes(value))
          whitespace
          trusted_html(label_text)
        end
      end
    end

    def radio_attributes(value)
      {
        type: :radio,
        name: field.dom.name,
        id: radio_id(value),
        value: value,
        checked: option_checked?(value)
      }.merge(@attributes)
    end

    def radio_id(value)
      "#{field.dom.id}_#{value.to_s.parameterize(separator: "_")}"
    end

    def option_checked?(value)
      field.value.to_s == value.to_s
    end

    def radio_class
      classes = "radio"
      if wrapper_options[:wrap_class].present?
        classes += " #{wrapper_options[:wrap_class]}"
      end
      classes
    end

    def map_options(collection)
      Superform::Rails::OptionMapper.new(collection)
    end
  end
end
