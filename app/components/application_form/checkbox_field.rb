# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap checkbox field component with checkbox wrapper and slots
  class CheckboxField < Superform::Rails::Components::Checkbox
    include Phlex::Slotable
    include FieldWithHelp

    slot :between
    slot :append

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
      class_name = wrapper_options[:class_name]

      div(class: checkbox_class(class_name)) do
        label(for: field.dom.id) do
          yield
          plain(" #{label_text}")
          render_help_in_label_row
          render(between_slot) if between_slot
        end
        render_help_after_field
        render(append_slot) if append_slot
      end
    end
    # rubocop:enable Metrics/AbcSize

    def checkbox_class(class_name)
      wrap_class = "checkbox"
      wrap_class += " #{class_name}" if class_name.present?
      wrap_class
    end
  end
end
