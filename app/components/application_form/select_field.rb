# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap select field component with form-group wrapper and slots
  class SelectField < Superform::Rails::Components::Select
    include Phlex::Rails::Helpers::ClassNames
    include Phlex::Slotable
    include FieldWithHelp

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
      label_option = wrapper_options[:label]
      show_label = label_option != false
      label_text = if label_option.is_a?(String)
                     label_option
                   else
                     field.key.to_s.humanize
                   end
      inline = wrapper_options[:inline] || false
      wrap_class = wrapper_options[:wrap_class]

      div(class: form_group_class("form-group", inline, wrap_class)) do
        render_label_row(label_text, inline) if show_label
        yield
        render_help_after_field
        render(append_slot) if append_slot
      end
    end
    # rubocop:enable Metrics/AbcSize

    def render_label_row(label_text, inline)
      display = inline ? "d-inline-flex" : "d-flex"

      div(class: "#{display} justify-content-between") do
        div do
          label(for: field.dom.id, class: "mr-3") { label_text }
          render_help_in_label_row
          render_between_slot
        end
      end
    end

    def form_group_class(base, inline, wrap_class)
      classes = base
      classes += " form-inline" if inline && base == "form-group"
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end
  end
end
