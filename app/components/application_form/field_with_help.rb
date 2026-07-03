# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared module for rendering help blocks on form fields.
  # Default: plain always-visible block below the field.
  # Pass `help_collapse: true` to render a collapsible well with a
  # question-mark trigger icon next to the label instead.
  module FieldWithHelp
    def render_help_in_label_row
      render_help_icon if help_slot && wrapper_options[:help_collapse]
    end

    def render_help_after_field
      return unless help_slot

      if wrapper_options[:help_collapse]
        render_collapsed_help_text
      else
        render_plain_help_text
      end
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

    def help_id
      "#{field.dom.id}_help"
    end

    def render_help_icon
      span(class: between_class) do
        render(::Components::Link.new(
                 type: :collapse_toggle,
                 target_id: help_id,
                 class: "info-collapse-trigger"
               )) { render(::Components::Icon.new(type: :question)) }
      end
    end

    def render_collapsed_help_text
      render(::Components::CollapseDiv.new(id: help_id)) do
        render(::Components::Help::Block.new(well: true)) { render(help_slot) }
      end
    end

    def render_plain_help_text
      render(::Components::Help::Block.new(id: help_id)) { render(help_slot) }
    end
  end
end
