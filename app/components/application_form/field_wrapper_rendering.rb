# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared field-wrapper skeleton: the form-group div, its Bootstrap
  # classes, and the label -> prepend -> [field content] -> append ->
  # help rendering order (help_placement: :above moves help ahead of
  # prepend instead). Every simple field type (TextField,
  # TextareaField, ...) wants this same skeleton; only the field
  # content itself (an <input>, a <textarea>, ...) differs. Help
  # renders inside this div, as part of the same form-group -- see
  # SelectRangeField for the one component that renders it outside
  # instead (its two side-by-side columns can't host a block-level
  # help without breaking the one-line layout).
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
      classes
    end

    def prepend_present?
      respond_to?(:prepend_slot) && prepend_slot
    end

    def append_present?
      respond_to?(:append_slot) && append_slot
    end

    def render_with_wrapper(&block)
      div(class: wrapper_class, data: wrapper_options[:wrap_data]) do
        render_label_row(label_text, inline?) if show_label?
        render_between_block
        render_help_after_field if help_placement_above?
        render_wrapper_body(&block)
        render_help_after_field unless help_placement_above?
      end
    end

    def render_wrapper_body
      render(prepend_slot) if prepend_present?
      yield
      render(append_slot) if append_present?
    end
  end
end
