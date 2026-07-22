# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared module for rendering help blocks on form fields.
  # Default: plain always-visible block below the field.
  # Pass `help_collapse: true` to render a collapsible well with a
  # question-mark trigger icon next to the label instead.
  module FieldWithHelp
    # Field classes (`DateField`, `TextField`, etc.) extend `Phlex::HTML`
    # directly rather than living as a direct `Components::*` constant,
    # so Phlex::Kit's `const_added` hook never fires for them and they
    # get no Kit-sugar bare methods (`Help(...)`, `Icon(...)`, etc.) on
    # their own. `include Components` here restores it transitively —
    # Ruby's module inclusion carries `Components`'s accumulated Kit
    # instance methods (and its `Phlex::Kit::LazyLoader` fallback) into
    # every class that includes this module. See
    # `.claude/rules/phlex_reference.md`'s Kit-syntax section for the
    # full mechanism.
    include ::Components
    # `::Components` above only carries Kit-sugar bare methods, not
    # Components::Base's other instance methods -- `append_colon`
    # (used by FieldLabelRow#label_text) needs its own explicit
    # include for the same reason Kit sugar does: these field classes
    # don't inherit Components::Base.
    include Components::Localization

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
        Link(type: :collapse_toggle,
             target_id: help_id,
             class: "info-collapse-trigger") { Icon(type: :question) }
      end
    end

    def render_collapsed_help_text
      Collapsible(id: help_id) do
        Help(well: true) { render(help_slot) }
      end
    end

    def render_plain_help_text
      Help(id: help_id) { render(help_slot) }
    end
  end
end
