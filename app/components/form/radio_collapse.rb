# frozen_string_literal: true

# Renders one radio_field option wired into a collapse-switch group:
# adds `data-action="change->collapse-switch#switch"`, merged with
# any caller-supplied `data:`. The caller still renders the matching
# `Collapsible(data: { collapse_switch_target: "panel",
# collapse_switch_type: <value> })` panel separately (same split
# `CheckboxCollapse` uses for its collapse target), and still wraps
# the whole group in `div(data: { controller: "collapse-switch" })`
# -- this component only standardizes the repeated per-radio wiring,
# not the group-level mechanism.
#
# @param form [Components::ApplicationForm] the parent form
# @param field [Symbol, String] the field name
# @param option_value [String, Integer, Float] this option's value --
#   not named `value:`, since that's reserved (per MO's
#   FieldProxy/radio_field convention) for the field's currently
#   selected value, forwarded through to radio_field via
#   `attributes:`/any other keyword, not a named prop here.
# @param label [String, Symbol] the label text, or a translation key
# Any other keyword (including `value:`, the selected value) is
# forwarded to radio_field.
class Components::Form::RadioCollapse < Components::Base
  prop :form, ::Components::ApplicationForm
  prop :field, _Union(Symbol, String)
  prop :option_value, _Union(String, Integer, Float)
  prop :label, _Union(String, Symbol)
  prop :attributes, _Hash(Symbol, _Any), :**

  def view_template
    @form.radio_field(@field, [@option_value, @label], **merged_attrs)
  end

  private

  def merged_attrs
    data = { action: "change->collapse-switch#switch" }.
           merge(@attributes[:data] || {})
    @attributes.merge(data: data)
  end
end
