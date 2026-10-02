# frozen_string_literal: true

# Collapsible panel of checkboxes for a has-many-through membership
# field (e.g. a form's project or species-list checkboxes). Default
# collapsed unless something's already checked; checked rows float to
# the top, the rest sorted alphabetically by title.
#
# @param form [Components::ApplicationForm] the parent form, to call
#   checkbox_field
# @param type [Symbol] singular -- :project or :species_list. Drives
#   the model-bound field (`:"#{type}_ids"`), the panel heading
#   (`type.pluralize.ti`), and the panel id
#   (`"#{form_object_name}_#{type.pluralize}"`)
# @param form_object_name [String] the form object's name, e.g.
#   "observation" -- used to build the sentinel hidden input's raw
#   `name=` (`"#{form_object_name}[#{field}][]"`), since the sentinel
#   bypasses checkbox_field's namespacing, and the panel id
# @param objects [Array<Project, SpeciesList>] candidate records
# @param checked_ids [Array<Integer>]
# @param disabled_ids [Array<Integer>]
# @param help_text [String, nil] rendered via a single shared
#   `Help(...)` call, after the block (if any) and before the
#   checkbox list
# @param expanded [Boolean, nil] override the default
#   (`checked_ids.any?`) -- e.g. to also expand on a constraint warning
class Components::Form::CheckboxPanel < Components::Base
  prop :form, ::Components::ApplicationForm
  prop :type, Symbol
  prop :form_object_name, String
  prop :objects, _Array(_Union(::Project, ::SpeciesList))
  prop :checked_ids, _Array(Integer), default: -> { [] }
  prop :disabled_ids, _Array(Integer), default: -> { [] }
  prop :help_text, _Nilable(String), default: nil
  prop :expanded, _Nilable(_Boolean), default: nil

  def view_template(&block)
    render(panel) do |p|
      p.with_heading { type_plural.ti }
      p.with_body(collapse: true) do
        yield if block
        render_help_text
        render_checkbox_list
      end
    end
  end

  private

  def render_help_text
    return unless @help_text

    Help(content: @help_text)
  end

  def type_plural
    @type.to_s.pluralize.to_sym
  end

  def field
    :"#{@type}_ids"
  end

  def panel_id
    "#{@form_object_name}_#{type_plural}"
  end

  def panel
    Components::Panel.new(
      panel_id: panel_id,
      collapsible: true,
      collapse_target: "##{panel_id}_inner",
      expanded: expanded?
    )
  end

  def expanded?
    @expanded.nil? ? @checked_ids.any? : @expanded
  end

  def sentinel_name
    "#{@form_object_name}[#{field}][]"
  end

  def render_checkbox_list
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
