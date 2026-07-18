# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap textarea field component with form-group wrapper and slots
  class TextareaField < Superform::Rails::Components::Textarea
    include Phlex::Slotable
    include FieldWithHelp
    include FieldLabelRow

    slot :between
    slot :label_end
    slot :prepend
    slot :append
    slot :help

    # Make slot accessors public (Phlex::Slotable makes them private by default)
    public :between_slot, :label_end_slot, :prepend_slot, :append_slot,
           :help_slot

    attr_reader :wrapper_options

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

    def render_with_wrapper
      div(class: wrapper_class, data: wrapper_options[:wrap_data]) do
        render_label_row(label_text, inline?) if show_label?
        # `prepend` renders between the label row and the field itself
        # (symmetric with `append`, which renders after the field) --
        # e.g. a full-width control that drives the field.
        render(prepend_slot) if prepend_slot
        yield
        render_help_after_field
        render(append_slot) if append_slot
      end
    end

    def show_label?
      wrapper_options[:label] != false
    end

    def inline?
      wrapper_options[:inline] || false
    end

    def wrapper_class
      form_group_class("form-group", inline?, wrapper_options[:wrap_class])
    end

    def form_group_class(base, inline, wrap_class)
      classes = base
      classes += " form-inline" if inline && base == "form-group"
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end
  end
end
