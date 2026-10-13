# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared module for rendering help blocks on form fields. Default:
  # plain always-visible block below the field. `help_collapse: true`
  # renders a collapsible well with a question-mark trigger instead;
  # add `help_well: false` to drop the well styling but keep the
  # collapsible behavior.
  module FieldWithHelp
    # Field classes extend `Phlex::HTML` directly, so Kit sugar
    # doesn't fire for them -- this restores it transitively. See
    # `.claude/rules/phlex_reference.md`'s Kit-syntax section.
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

    # `form-between` is a block-level spacer, so it doesn't work on
    # an inline field row -- that case gets a trailing margin applied
    # directly instead. A block-level field uses `form-between`.
    def between_class
      wrapper_options[:inline] ? "mr-3" : "form-between"
    end

    private

    def help_id
      "#{field.dom.id}_help"
    end

    # Trailing space before the row's next sibling (an inline field's
    # input) lives on the row itself (FieldLabelRow#render_label_with_
    # appends/#render_label_flex_row), not on this span -- putting it
    # here would double up with a later append's leading margin.
    def render_help_icon
      span(class: "ml-2") do
        Link(type: :collapse_toggle,
             target_id: help_id,
             class: "info-collapse-trigger") do
          Icon(type: :question, title: :help.ti)
        end
      end
    end

    def render_collapsed_help_text
      Collapsible(id: help_id) do
        Help(well: wrapper_options.fetch(:help_well, true)) do
          render(help_slot)
        end
      end
    end

    # help_placement: :above drops the help block's default top margin
    # -- see FieldLabelRow#label_class's matching mb-0 on the label,
    # and FieldLabelRow#help_placement_above? for the shared check.
    # respond_to? guards SelectRangeField, the one class that includes
    # this module without FieldLabelRow.
    def render_plain_help_text
      above = respond_to?(:help_placement_above?) && help_placement_above?
      extra_class = "mt-0" if above
      Help(id: help_id, class: extra_class) { render(help_slot) }
    end
  end
end
