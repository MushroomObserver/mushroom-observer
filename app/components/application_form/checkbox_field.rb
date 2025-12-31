# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap checkbox field component with checkbox wrapper and slots
  class CheckboxField < Superform::Rails::Components::Checkbox
    include Phlex::Slotable
    include FieldWithHelp

    slot :between
    slot :append
    slot :help

    public :between_slot, :append_slot, :help_slot

    attr_reader :wrapper_options

    def initialize(field, attributes:, wrapper_options: {})
      super(field, attributes: attributes)
      @wrapper_options = wrapper_options
    end

    def view_template
      label_option = wrapper_options[:label]

      if label_option == false
        # Render checkbox without label wrapper
        super
      else
        render_with_wrapper do
          # Inherits proper checkbox behavior from Superform
          # (hidden input + checked)
          super
        end
      end
    end

    private

    # rubocop:disable Metrics/AbcSize
    def render_with_wrapper
      label_option = wrapper_options[:label]
      label_text = if label_option.is_a?(String)
                     label_option
                   else
                     field.key.to_s.humanize
                   end
      wrap_class = wrapper_options[:wrap_class]

      div(class: checkbox_class(wrap_class)) do
        label(for: field.dom.id, **label_attributes) do
          yield
          plain(" #{label_text}")
          render_help_in_label_row
          render_between_slot
        end
        render_help_after_field
        render(append_slot) if append_slot
      end
    end
    # rubocop:enable Metrics/AbcSize

    def label_attributes
      {}.tap do |attrs|
        attrs[:data] = wrapper_options[:label_data] if label_data?
        attrs[:aria] = wrapper_options[:label_aria] if label_aria?
      end
    end

    def label_data?
      wrapper_options[:label_data]
    end

    def label_aria?
      wrapper_options[:label_aria]
    end

    def checkbox_class(wrap_class)
      classes = "checkbox"
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end
  end
end
