# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared module for rendering collapsible help blocks on form fields
  module FieldWithHelp
    def render_help_in_label_row
      render_help_icon if help_slot
    end

    def render_help_after_field
      render_help_text if help_slot
    end

    # Renders the between slot with appropriate margin class
    def render_between_slot
      return unless between_slot

      span(class: between_class) { render(between_slot) }
    end

    # Mirrors ERB `forms_helper.rb#check_for_help_block`: an inline
    # field row uses `mr-3` (since `form-between` is a block-level
    # spacer that doesn't apply); a block-level field uses
    # `form-between` (which already supplies its own spacing).
    def between_class
      wrapper_options[:inline] ? "mr-3" : "form-between"
    end

    private

    def render_help_icon
      help_id = "#{field.dom.id}_help"
      span(class: between_class) do
        a(href: "##{help_id}",
          class: "info-collapse-trigger",
          role: "button",
          data: { toggle: "collapse" },
          aria: { expanded: "false", controls: help_id }) do
          span(class: "glyphicon glyphicon-question-sign link-icon")
        end
      end
    end

    def render_help_text
      help_id = "#{field.dom.id}_help"
      div(class: "collapse", id: help_id) do
        div(class: "well well-sm mb-3 help-block position-relative") do
          render(help_slot)
        end
      end
    end
  end
end
