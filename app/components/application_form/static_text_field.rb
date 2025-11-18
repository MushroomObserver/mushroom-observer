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
      inline = @wrapper_options[:inline] || false
      wrap_class = @wrapper_options[:wrap_class]
      label_text = @wrapper_options[:label]

      div(class: form_group_class("form-group", inline, wrap_class)) do
        render_label(label_text, inline) if label_text
        p(class: "form-control-static") { display_text }
      end
    end

    private

    def display_text
      @wrapper_options[:value] || @wrapper_options[:text] || ""
    end

    def form_group_class(base, inline, wrap_class)
      classes = base
      classes += " form-inline" if inline && base == "form-group"
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end

    def render_label(text, _inline)
      label(class: "mr-3") { text } if text
    end
  end
end
