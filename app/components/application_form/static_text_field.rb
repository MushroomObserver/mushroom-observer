# frozen_string_literal: true

# Static text field component for Superform.
# Renders a label + read-only text display (no input field).
#
# Used for displaying non-editable information in a form layout.
#
# @example Basic usage
#   field(:name).static(
#     wrapper_options: { label: "Name", value: "John Doe" }
#   )
class Components::ApplicationForm < Superform::Rails::Form
  class StaticTextField < Phlex::HTML
    include Phlex::Slotable
    include FieldWithHelp
    include FieldLabelRow
    include FieldWrapperRendering

    slot :help

    public :help_slot

    attr_reader :wrapper_options, :field, :attributes

    def initialize(field, wrapper_options: {}, **attributes)
      super()
      @field = field
      @attributes = attributes
      @wrapper_options = wrapper_options
    end

    def view_template
      render_with_wrapper do
        p(class: static_text_class) { display_text }
      end
    end

    private

    def display_text
      @wrapper_options[:value] || @wrapper_options[:text] || ""
    end

    # `.form-control-plaintext` is `display: block; width: 100%` --
    # Bootstrap 4's `.form-inline .form-control` override doesn't
    # cover this class, so it stays full-width even as a flex item,
    # forcing the next sibling onto a new line.
    def static_text_class
      return "form-control-plaintext" unless inline?

      "form-control-plaintext d-inline-block w-auto"
    end
  end
end
