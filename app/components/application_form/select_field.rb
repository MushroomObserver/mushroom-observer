# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap select field component with form-group wrapper and slots
  class SelectField < Superform::Rails::Components::Select
    include Phlex::Rails::Helpers::ClassNames
    include Phlex::Slotable

    slot :between
    slot :append

    attr_reader :wrapper_options

    def initialize(field, collection:, attributes:, wrapper_options: {})
      super(field, collection: collection, attributes: attributes)
      @wrapper_options = wrapper_options
    end

    def view_template(&options_block)
      render_with_wrapper do
        if options_block
          select(**attributes, class: select_classes, &options_block)
        else
          select(**attributes, class: select_classes) do
            options(*@collection)
          end
        end
      end
    end

    private

    def select_classes
      class_names(attributes[:class], "form-control")
    end

    # rubocop:disable Metrics/AbcSize
    def render_with_wrapper
      label_text = wrapper_options[:label] || field.key.to_s.humanize
      inline = wrapper_options[:inline] || false
      class_name = wrapper_options[:class_name]

      div(class: form_group_class("form-group", inline, class_name)) do
        render_label_row(label_text, inline)
        yield
        render(append_slot) if append_slot
      end
    end
    # rubocop:enable Metrics/AbcSize

    def render_label_row(label_text, inline)
      display = inline ? "d-inline-flex" : "d-flex"

      div(class: "#{display} justify-content-between") do
        div do
          label(for: field.dom.id, class: "mr-3") { label_text }
          render(between_slot) if between_slot
        end
      end
    end

    def form_group_class(base, inline, class_name)
      wrap_class = base
      wrap_class += " form-inline" if inline && base == "form-group"
      wrap_class += " #{class_name}" if class_name.present?
      wrap_class
    end
  end
end
