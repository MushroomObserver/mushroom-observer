# frozen_string_literal: true

# Hidden field component for Superform.
# Renders a label + static text display + hidden input field.
#
# This is used when you want to show the user what value is being submitted
# but prevent them from editing it.
#
# @example Basic usage
#   field(:user_id).hidden(
#     wrapper_options: { label: "User:", value: "John Doe" }
#   )
class Components::ApplicationForm
  class HiddenField < FieldWithHelp
    def view_template
      div(class: wrapper_class) do
        render_label
        p(@wrapper_options[:value] || @wrapper_options[:text] || "",
          class: "form-control-static")
        input(**field_attributes)
      end
    end

    private

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
