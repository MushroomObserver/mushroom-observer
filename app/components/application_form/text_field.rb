# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap text input field component with form-group wrapper and slots
  class TextField < Superform::Rails::Components::Input
    include Phlex::Slotable
    include FieldWithHelp
    include FieldLabelRow
    include FieldWrapperRendering
    include InputGroupAddon

    slot :between
    slot :label_end
    slot :append
    slot :help

    # Make slot accessors public (Phlex::Slotable makes them private by default)
    public :between_slot, :label_end_slot, :append_slot, :help_slot

    def initialize(field, wrapper_options: {}, **attributes)
      super(field, **attributes)
      @wrapper_options = wrapper_options
    end

    def view_template
      if bare_input?
        input(**attributes, class: class_names(attributes[:class],
                                               "form-control"))
      else
        render_with_wrapper do
          render_field_input do
            input(**attributes, class: class_names(attributes[:class],
                                                   "form-control"))
          end
        end
      end
    end

    private

    def bare_input?
      attributes[:type] == "hidden" ||
        (wrapper_options[:label] == false && !help_slot)
    end

    def render_field_input(&block)
      if wrapper_options[:button]
        render_input_group_button(&block)
      elsif wrapper_options[:addon]
        render_input_group_addon(&block)
      else
        yield
      end
    end
  end
end
