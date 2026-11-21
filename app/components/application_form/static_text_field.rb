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
        p(class: "form-control-static") { display_text }
      end
    end

    private

    def display_text
      @wrapper_options[:value] || @wrapper_options[:text] || ""
    end
  end
end
