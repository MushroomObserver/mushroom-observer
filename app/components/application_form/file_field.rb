# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap file input field component with form-group wrapper and slots
  class FileField < Superform::Rails::Components::Input
    include Phlex::Rails::Helpers::ClassNames
    include Phlex::Slotable

    slot :between
    slot :append

    attr_reader :wrapper_options

    def initialize(field, attributes:, wrapper_options: {})
      super(field, attributes: attributes)
      @wrapper_options = wrapper_options
    end

    def view_template
      # File fields always get wrappers
      render_with_wrapper do
        input(**attributes, type: "file")
      end
    end

    private

    def render_with_wrapper
      label_option = wrapper_options[:label]
      show_label = label_option != false
      label_text = if label_option.is_a?(String)
                     label_option
                   else
                     field.key.to_s.humanize
                   end
      wrap_class = wrapper_options[:wrap_class]

      div(class: form_group_class("form-group", wrap_class)) do
        render_label_row(label_text) if show_label
        render(between_slot) if between_slot
        yield
        render(append_slot) if append_slot
      end
    end

    def render_label_row(label_text)
      label(for: field.dom.id) { label_text }
    end

    def form_group_class(base, wrap_class)
      classes = base
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end
  end
end
