# frozen_string_literal: true

# Renders a checkbox that triggers a Bootstrap collapse section.
# Puts `data-toggle="collapse"` and `data-target` on the `<label>`
# (not the `<input>`), matching the naming-reasons trigger pattern.
#
# Extra `checkbox_field` options (help:, wrap_class:, data:, etc.) go in
# `attributes:` and are forwarded verbatim. Any `label_data:` or
# `label_aria:` in `attributes:` are merged with the collapse trigger
# attrs.
#
# @param form [Components::ApplicationForm] the parent form
# @param field [Symbol] the field name
# @param target_id [String] id of the collapse target (no leading #)
# @param label [String, Symbol] the label text, or a translation key --
#   passed straight through to checkbox_field, which resolves a Symbol
#   via `.t` itself (see FieldLabelRow#resolved_label_text).
# @param expanded [Boolean] initial expanded state (default: false)
# @param attributes [Hash] extra options forwarded to checkbox_field
class Components::Form::CheckboxCollapse < Components::Base
  prop :form, ::Components::ApplicationForm
  prop :field, Symbol
  prop :target_id, String
  prop :label, _Union(String, Symbol)
  prop :expanded, _Boolean, default: false
  prop :attributes, _Hash(Symbol, _Any), default: -> { {} }

  def view_template
    @form.checkbox_field(
      @field,
      label: @label,
      label_data: collapse_label_data,
      label_aria: collapse_label_aria,
      **passthrough_attrs
    )
  end

  private

  def collapse_label_data
    { toggle: "collapse", target: "##{@target_id}" }.
      merge(@attributes[:label_data] || {})
  end

  def collapse_label_aria
    { expanded: @expanded.to_s, controls: @target_id }.
      merge(@attributes[:label_aria] || {})
  end

  def passthrough_attrs
    @attributes.except(:label_data, :label_aria)
  end
end
