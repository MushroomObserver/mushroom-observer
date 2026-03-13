# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap text input field component with form-group wrapper and slots
  class TextField < Superform::Rails::Components::Input
    include Phlex::Slotable
    include FieldWithHelp
    include FieldLabelRow

    slot :between
    slot :label_end
    slot :append
    slot :help

    # Make slot accessors public (Phlex::Slotable makes them private by default)
    public :between_slot, :label_end_slot, :append_slot, :help_slot

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

    def render_with_wrapper(&field_input)
      div(class: wrapper_class, data: wrapper_options[:wrap_data]) do
        render_label_row(label_text, inline?) if show_label?
        render_field_input(&field_input)
        render_help_after_field
        render(append_slot) if append_slot
      end
    end

    def show_label?
      wrapper_options[:label] != false
    end

    def label_text
      label_option = wrapper_options[:label]
      label_option.is_a?(String) ? label_option : field.key.to_s.humanize
    end

    def inline?
      wrapper_options[:inline] || false
    end

    def wrapper_class
      form_group_class("form-group", inline?, wrapper_options[:wrap_class])
    end

    def render_field_input(&block)
      if wrapper_options[:button]
        render_input_with_button(&block)
      elsif wrapper_options[:addon]
        render_input_with_addon(&block)
      else
        yield
      end
    end

    def render_input_with_button
      div(class: "input-group") do
        yield
        span(class: "input-group-btn") do
          button(type: "button", class: "btn btn-default",
                 data: wrapper_options[:button_data] || {}) do
            wrapper_options[:button]
          end
        end
      end
    end

    def render_input_with_addon
      div(class: "input-group") do
        yield
        span(class: "input-group-addon") { wrapper_options[:addon] }
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
