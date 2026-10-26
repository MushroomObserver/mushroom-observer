# frozen_string_literal: true

# Read-only field component for Superform.
# Renders a label + static text display + hidden input field.
#
# This is used when you want to show the user what value is being submitted
# but prevent them from editing it.
#
# @example Basic usage
#   field(:user_id).read_only(
#     wrapper_options: { label: "User", value: "John Doe" }
#   )
class Components::ApplicationForm < Superform::Rails::Form
  class ReadOnlyField < Phlex::HTML
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
        p(class: static_text_class) do
          @wrapper_options[:value] || @wrapper_options[:text] || ""
        end
        input(**field_attributes)
      end
    end

    private

    # `.form-control-plaintext` is `display: block; width: 100%` --
    # Bootstrap 4's `.form-inline .form-control` override doesn't
    # cover this class, so it stays full-width even as a flex item,
    # forcing the next sibling onto a new line.
    def static_text_class
      return "form-control-plaintext" unless inline?

      "form-control-plaintext d-inline-block w-auto"
    end

    def field_attributes
      {
        type: "hidden",
        name: field.dom.name,
        id: field.dom.id,
        value: field.value
      }.merge(@attributes)
    end
  end
end
