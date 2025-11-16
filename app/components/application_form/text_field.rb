# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap text input field component with form-group wrapper and slots
  class TextField < Superform::Rails::Components::Input
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
      # Hidden fields don't get wrappers
      if attributes[:type] == "hidden"
        input(**attributes)
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
      label_text = wrapper_options[:label] || field.key.to_s.humanize
      inline = wrapper_options[:inline] || false
      class_name = wrapper_options[:class_name]

      div(class: form_group_class("form-group", inline, class_name)) do
        render_label_row(label_text, inline)
        render_field_input(&field_input)
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

    def render_field_input
      addon = wrapper_options[:addon]
      button = wrapper_options[:button]
      button_data = wrapper_options[:button_data] || {}

      if addon.present?
        div(class: "input-group") do
          yield
          span(class: "input-group-addon") { addon }
        end
      elsif button.present?
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

    def form_group_class(base, inline, class_name)
      wrap_class = base
      wrap_class += " form-inline" if inline && base == "form-group"
      wrap_class += " #{class_name}" if class_name.present?
      wrap_class
    end
  end
end
