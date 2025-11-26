# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap text input field component with form-group wrapper and slots
  class TextField < Superform::Rails::Components::Input
    include Phlex::Rails::Helpers::ClassNames
    include Phlex::Slotable
    include FieldWithHelp

    slot :between
    slot :label_end
    slot :append

    attr_reader :wrapper_options

    def initialize(field, attributes:, wrapper_options: {})
      super(field, attributes: attributes)
      @wrapper_options = wrapper_options
    end

    def view_template
      # Hidden fields and label:false don't get wrappers
      if attributes[:type] == "hidden" || wrapper_options[:label] == false
        input(**attributes, class: class_names(attributes[:class],
                                               "form-control"))
      else
        render_with_wrapper do
          input(**attributes, class: class_names(attributes[:class],
                                                 "form-control"))
        end
      end
    end

    private

    # rubocop:disable Metrics/AbcSize
    def render_with_wrapper(&field_input)
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
        render_field_input(&field_input)
        render_help_after_field
        render(append_slot) if append_slot
      end
    end
    # rubocop:enable Metrics/AbcSize

    def render_label_row(label_text, inline)
      # Simple label if no slots or help
      if !between_slot && !label_end_slot && !wrapper_options[:help]
        label(for: field.dom.id, class: "mr-3") { label_text }
      else
        display = inline ? "d-inline-flex" : "d-flex"
        div(class: "#{display} justify-content-between") do
          div do
            label(for: field.dom.id, class: "mr-3") { label_text }
            render_help_in_label_row
            render(between_slot) if between_slot
          end
          if label_end_slot
            div do
              render(label_end_slot)
            end
          end
        end
      end
    end

    def render_field_input
      button = wrapper_options[:button]
      button_data = wrapper_options[:button_data] || {}

      if button.present?
        div(class: "input-group") do
          yield
          span(class: "input-group-btn") do
            button(type: "button", class: "btn btn-default",
                   data: button_data) do
              button
            end
          end
        end
      else
        yield
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
