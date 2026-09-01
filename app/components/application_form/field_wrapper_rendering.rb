# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared field-wrapper skeleton: the form-group div, its Bootstrap
  # classes, and the label -> prepend -> [field content] -> help ->
  # append rendering order. Every simple field type (TextField,
  # TextareaField, ...) wants this same skeleton; only the field
  # content itself (an <input>, a <textarea>, ...) differs.
  #
  # `prepend`/`append` are optional per field type -- declare
  # `slot :prepend` (via Phlex::Slotable) only on the types that need
  # it. Guarded with `respond_to?`, the same pattern FieldLabelRow
  # already uses for `label_end_slot`.
  module FieldWrapperRendering
    attr_reader :wrapper_options

    private

    def show_label?
      wrapper_options[:label] != false
    end

    def inline?
      wrapper_options[:inline] || false
    end

    def wrapper_class
      form_group_class("form-group", inline?, wrapper_options[:wrap_class])
    end

    def form_group_class(base, inline, wrap_class)
      classes = base
      classes += " form-inline" if inline && base == "form-group"
      classes += " #{wrap_class}" if wrap_class.present?
      # Help renders as a sibling right after this div, not inside it
      # (see below) -- .help-block's own top margin already spaces it
      # from the field, so drop this div's own bottom margin to avoid
      # doubling up.
      classes += " mb-0" if help_present?
      classes
    end

    def prepend_present?
      respond_to?(:prepend_slot) && prepend_slot
    end

    def append_present?
      respond_to?(:append_slot) && append_slot
    end

    def between_present?
      respond_to?(:between_slot) && between_slot
    end

    # Only plain help renders an always-visible .help-block sibling
    # right after this div (what mb-0, above, is compensating for).
    # help_collapse: true renders a Collapsible that's hidden by
    # default -- dropping this div's bottom margin there would shrink
    # the gap to whatever field comes next, with no visible help-block
    # to justify it. help_placement: :above renders help inside this
    # div instead of as a trailing sibling, so there's no bottom-margin
    # doubling to compensate for either.
    def help_present?
      respond_to?(:help_slot) && help_slot &&
        !wrapper_options[:help_collapse] && !help_placement_above?
    end

    def render_with_wrapper(&block)
      div(class: wrapper_class, data: wrapper_options[:wrap_data]) do
        render_label_row(label_text, inline?) if show_label?
        render(between_slot) if between_present?
        render_help_after_field if help_placement_above?
        render_wrapper_body(&block)
      end
      render_help_after_field unless help_placement_above?
    end

    def render_wrapper_body
      render(prepend_slot) if prepend_present?
      yield
      render(append_slot) if append_present?
    end
  end
end
