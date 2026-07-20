# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap textarea field component with form-group wrapper and slots
  class TextareaField < Superform::Rails::Components::Textarea
    include Phlex::Slotable
    include FieldWithHelp
    include FieldLabelRow
    include FieldWrapperRendering

    slot :between
    slot :label_end
    slot :prepend
    slot :append
    slot :help

    # Make slot accessors public (Phlex::Slotable makes them private by default)
    public :between_slot, :label_end_slot, :prepend_slot, :append_slot,
           :help_slot

    def initialize(field, wrapper_options: {}, **attributes)
      super(field, **attributes)
      @wrapper_options = wrapper_options
    end

    def view_template(&content)
      render_with_wrapper do
        # Use value attribute, then field value, as default content
        default_value = attributes.delete(:value) || field.dom.value
        content ||= proc { default_value }
        textarea(**attributes, class: textarea_class, &content)
      end
    end

    private

    # `wrapper_options[:monospace] == true` appends `text-monospace` to
    # the textarea's class chain. Matches the ERB `text_area_with_label`
    # helper's `:monospace` option so callers (and direct component
    # instantiators) get the same emission either way.
    def textarea_class
      mono = "text-monospace" if wrapper_options[:monospace]
      class_names(attributes[:class], "form-control", mono)
    end
  end
end
