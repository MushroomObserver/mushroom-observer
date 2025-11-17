# frozen_string_literal: true

# Static text field component for Superform.
# Renders a label + read-only text display (no input field).
#
# Used for displaying non-editable information in a form layout.
#
# @example Basic usage
#   field(:name).static(
#     wrapper_options: { label: "Name:", value: "John Doe" }
#   )
class Components::ApplicationForm < Superform::Rails::Form
  class StaticTextField < Phlex::HTML
    include FieldWithHelp

    attr_reader :wrapper_options, :field, :attributes

    def initialize(field, attributes:, wrapper_options: {})
      super()
      @field = field
      @attributes = attributes
      @wrapper_options = wrapper_options
    end

    def view_template
      div(class: wrapper_class) do
        render_label
        p(display_text, class: "form-control-static")
      end
    end

    private

    def display_text
      @wrapper_options[:value] || @wrapper_options[:text] || ""
    end
  end
end
