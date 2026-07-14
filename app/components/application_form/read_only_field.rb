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
      inline = @wrapper_options[:inline] || false
      wrap_class = @wrapper_options[:wrap_class]

      div(class: form_group_class("form-group", inline, wrap_class)) do
        render_label(label_text, inline) if show_label?
        p(class: "form-control-static") do
          @wrapper_options[:value] || @wrapper_options[:text] || ""
        end
        input(**field_attributes)
      end
    end

    private

    def show_label?
      wrapper_options[:label] != false
    end

    def form_group_class(base, inline, wrap_class)
      classes = base
      classes += " form-inline" if inline && base == "form-group"
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end

    def render_label(text, _inline)
      label(for: field.dom.id, class: "mr-3") { text } if text
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
