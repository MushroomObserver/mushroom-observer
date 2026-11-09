# frozen_string_literal: true

# Scrollable, overflow-faded list of checkboxes for a has-many-through
# membership field (e.g. a form's project or species-list checkboxes).
# Checked rows float to the top, the rest sorted alphabetically by
# title. Owns only the list + its overflow wrap -- no panel chrome, no
# heading, no help text, no collapse behavior. A caller that wants
# those builds a `Components::Panel` (or a plain heading) around this
# component; a caller that doesn't supplies a "Projects"-style header
# directly instead.
#
# @param form [Components::ApplicationForm] the parent form, to call
#   checkbox_field
# @param type [Symbol] singular -- :project or :species_list. Drives
#   the model-bound field (`:"#{type}_ids"`).
# @param form_object_name [String] the form object's name, e.g.
#   "observation" -- used to build the sentinel hidden input's raw
#   `name=` (`"#{form_object_name}[#{field}][]"`), since the sentinel
#   bypasses checkbox_field's namespacing.
# @param objects [Array<Project, SpeciesList>] candidate records
# @param checked_ids [Array<Integer>]
# @param disabled_ids [Array<Integer>]
class Components::Form::OverflowCheckboxList < Components::Base
  prop :form, ::Components::ApplicationForm
  prop :type, Symbol
  prop :form_object_name, String
  prop :objects, _Array(_Union(::Project, ::SpeciesList))
  prop :checked_ids, _Array(Integer), default: -> { [] }
  prop :disabled_ids, _Array(Integer), default: -> { [] }

  def view_template
    div(class: "overflow-scroll-checklist",
        data: { controller: "overflow-fade" }) do
      # Sentinel: ensures the field key is always present in params
      # even when every checkbox is unchecked (Rack drops empty
      # arrays). Callers' controllers compact_blank this empty value.
      input(type: "hidden", name: sentinel_name, value: "",
            autocomplete: "off")
      ordered_objects.each { |object| render_checkbox(object) }
    end
  end

  private

  def field
    :"#{@type}_ids"
  end

  def sentinel_name
    "#{@form_object_name}[#{field}][]"
  end

  # Checked rows first, everything else alphabetical by title.
  def ordered_objects
    checked, unchecked = @objects.sort_by(&:title).
                         partition { |o| @checked_ids.include?(o.id) }
    checked + unchecked
  end

  def render_checkbox(object)
    @form.checkbox_field(
      field,
      label: false,
      disabled: @disabled_ids.include?(object.id)
    ) do |cb|
      cb.option(object.id, checked: @checked_ids.include?(object.id)) do
        whitespace
        plain(object.title)
      end
    end
  end
end
