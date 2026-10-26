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
    include Phlex::Rails::Helpers::ClassNames

    attr_reader :wrapper_options

    private

    def show_label?
      wrapper_options[:label] != false
    end

    def inline?
      wrapper_options[:inline] || false
    end

    def wrapper_class
      wrap_class = inline? ? nil : wrapper_options[:wrap_class]
      form_group_class("form-group", wrap_class)
    end

    def form_group_class(base, wrap_class)
      classes = base
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end

    # `.form-inline .form-group` already zeroes the inner div's
    # margin-bottom, so `wrap_class` (if given) lands on this ancestor
    # div instead -- the default `mb-3` fits a single standalone
    # inline field; a group of fields sharing one block of spacing
    # (e.g. Names::Form's locked fields) passes `wrap_class: "mb-0"`
    # per field and puts the mb-3 on the group's outer wrapper.
    def inline_wrapper_class
      wrapper_options[:wrap_class] || "mb-3"
    end

    def prepend_present?
      respond_to?(:prepend_slot) && prepend_slot
    end

    def append_present?
      respond_to?(:append_slot) && append_slot
    end

    # `inline?` wraps the form-group in a `.form-inline` ancestor div,
    # so Bootstrap 3's `.form-inline .form-group` descendant selector
    # matches as designed -- putting both classes on the form-group
    # div itself matches nothing, since that selector needs two
    # distinct elements.
    def render_with_wrapper(&block)
      if inline?
        div(class: class_names("form-inline", inline_wrapper_class)) do
          render_form_group(&block)
        end
      else
        render_form_group(&block)
      end
    end

    def render_form_group(&block)
      div(class: wrapper_class, data: wrapper_options[:wrap_data]) do
        render_label_row(label_text, inline?) if show_label?
        render_between_block
        render_help_after_field if help_placement_above?
        render_wrapper_body(&block)
        render_help_after_field unless help_placement_above?
      end
    end

    def render_wrapper_body(&block)
      render(prepend_slot) if prepend_present?
      if wrapper_options[:wrap_append_in_input_group] && append_present?
        render_append_in_input_group(&block)
      else
        yield
        render(append_slot) if append_present?
      end
    end

    # Opt-in for fields whose append content (e.g. the autocompleter's
    # dropdown-menu) needs `position: relative` scoped to just the
    # field, not the whole form-group -- `.form-group.dropdown`'s
    # `position: relative` sits too high in the tree (it also wraps
    # the label and help text), so a `position: absolute; top: 100%`
    # descendant lands below all of that instead of below the field.
    # `Components::InputGroup` already provides this tight wrapper
    # (and its CSS is already scoped to .input-group, not every
    # form-group), so this reuses it rather than adding a new rule.
    def render_append_in_input_group
      InputGroup(**input_group_attributes) do
        yield
        render(append_slot)
      end
    end

    def input_group_attributes
      if wrapper_options[:input_group_class].present?
        { class: wrapper_options[:input_group_class] }
      else
        {}
      end
    end
  end
end
