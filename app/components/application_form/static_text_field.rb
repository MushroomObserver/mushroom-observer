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
class Components::ApplicationForm
  class StaticTextField < FieldWithHelp
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
