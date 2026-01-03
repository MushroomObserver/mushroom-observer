# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared label row rendering for form field components
  module FieldLabelRow
    def render_label_row(label_text, inline)
      if simple_label?
        label(for: field.dom.id, class: "mr-3") { label_text }
      else
        render_label_flex_row(label_text, inline)
      end
    end

    def simple_label?
      has_label_end = respond_to?(:label_end_slot) && label_end_slot
      has_between = between_slot || wrapper_options[:between]
      has_help = respond_to?(:help_slot) && help_slot
      !has_between && !has_label_end && !has_help
    end

    def render_label_flex_row(label_text, inline)
      display = inline ? "d-inline-flex" : "d-flex"
      div(class: "#{display} justify-content-between") do
        render_label_with_help(label_text)
        render_label_end_slot
      end
    end

    def render_label_with_help(label_text)
      div do
        label(for: field.dom.id, class: "mr-3") { label_text }
        render_help_in_label_row
        render_between_content
      end
    end

    def render_between_content
      render_between_option
      render(between_slot) if between_slot
    end

    def render_between_option
      between = wrapper_options[:between]
      return unless between

      span(class: "help-note") { between_text(between) }
    end

    def between_text(between)
      [:optional, :required].include?(between) ? "(#{between.l})" : between
    end

    def render_label_end_slot
      return unless respond_to?(:label_end_slot) && label_end_slot

      render(label_end_slot)
    end
  end
end
