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

    def initialize(field, *options, attributes: {}, wrapper_options: {})
      super(field, *options, attributes: attributes)
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

    def render_with_wrapper(&checkbox_block)
      div(class: checkbox_class) do
        label(for: checkbox_id, **label_attributes) do
          render_content(&checkbox_block)
          render_help_in_label_row
        end
        render_help_after_field
        render(append_slot) if append_slot
      end
    end

    # Use custom ID if provided, otherwise use Superform's generated ID
    def checkbox_id
      attributes[:id] || field.dom.id
    end

    # MO's default render order is checkbox-then-label
    def render_content
      if label_position_before?
        plain(label_text)
        whitespace
        render_between_slot
        yield
      else
        yield
        render_between_slot
        whitespace
        plain(label_text)
      end
    end

    # Pass `label_position: :before` to render label-then-checkbox
    def label_position_before?
      wrapper_options[:label_position] == :before
    end

    def label_text
      label_option = wrapper_options[:label]
      label_option.is_a?(String) ? label_option : field.key.to_s.humanize
    end

    def checkbox_class
      classes = "checkbox"
      classes += " #{wrapper_options[:wrap_class]}" if wrap_class?
      classes
    end

    def wrap_class?
      wrapper_options[:wrap_class].present?
    end

    def label_attributes
      {}.tap do |attrs|
        attrs[:class] = wrapper_options[:label_class] if label_class?
        attrs[:data] = wrapper_options[:label_data] if label_data?
        attrs[:aria] = wrapper_options[:label_aria] if label_aria?
      end
    end

    def label_class?
      wrapper_options[:label_class]
    end

    def label_data?
      wrapper_options[:label_data]
    end

    def label_aria?
      wrapper_options[:label_aria]
    end
  end
end
