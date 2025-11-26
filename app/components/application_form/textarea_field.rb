# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap textarea field component with form-group wrapper and slots
  class TextareaField < Superform::Rails::Components::Textarea
    include Phlex::Rails::Helpers::ClassNames
    include Phlex::Slotable
    include FieldWithHelp
    include FieldLabelRow

    slot :between
    slot :label_end
    slot :append

    attr_reader :wrapper_options

    def initialize(field, attributes:, wrapper_options: {})
      super(field, attributes: attributes)
      @wrapper_options = wrapper_options
    end

    def view_template(&content)
      render_with_wrapper do
        # Use value attribute, then field value, as default content
        default_value = attributes.delete(:value) || field.dom.value
        content ||= proc { default_value }
        textarea(**attributes, class: class_names(attributes[:class],
                                                  "form-control"), &content)
      end
    end

    private

    # rubocop:disable Metrics/AbcSize
    def render_with_wrapper
      label_option = wrapper_options[:label]
      show_label = label_option != false
      label_text = if label_option.is_a?(String)
                     label_option
                   else
                     field.key.to_s.humanize
                   end
      inline = wrapper_options[:inline] || false
      wrap_class = wrapper_options[:wrap_class]
      wrap_data = wrapper_options[:wrap_data]

      div(class: form_group_class("form-group", inline, wrap_class),
          data: wrap_data) do
        render_label_row(label_text, inline) if show_label
        yield
        render_help_after_field
        render(append_slot) if append_slot
      end
    end
    # rubocop:enable Metrics/AbcSize

    def form_group_class(base, inline, wrap_class)
      classes = base
      classes += " form-inline" if inline && base == "form-group"
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end
  end
end
