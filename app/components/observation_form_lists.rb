# frozen_string_literal: true

# Species lists section of the observation form.
# Renders a collapsible panel with species list checkboxes.
#
# @param form [Components::ApplicationForm] the parent form
# @param lists [Array<SpeciesList>] available species lists
# @param list_checks [Hash] list_id => checked state
class Components::ObservationFormLists < Components::Base
  prop :form, _Any
  prop :lists, _Array(SpeciesList)
  prop :list_checks, Hash

  def view_template
    render(panel) do |p|
      p.with_heading { :SPECIES_LISTS.l }
      p.with_body(collapse: true) { render_body }
    end
  end

  private

  def panel
    Components::Panel.new(
      panel_id: "observation_lists",
      collapsible: true,
      collapse_target: "#observation_lists_inner",
      expanded: @list_checks.any?
    )
  end

  def render_body
    @form.namespace(:list) do |list_ns|
      render_help_text
      render_list_checkboxes(list_ns)
    end
  end

  def render_help_text
    p { :form_observations_list_help.t }
  end

  def render_list_checkboxes(list_ns)
    div(class: "overflow-scroll-checklist") do
      @lists.each do |list|
        render_list_checkbox(list_ns, list)
      end
    end
  end

  def render_list_checkbox(list_ns, list)
    field_name = :"id_#{list.id}"
    checked = @list_checks[list.id]
    disabled = !permission?(list)

    render(list_ns.field(field_name).checkbox(
             wrapper_options: { label: list.title },
             checked: checked,
             disabled: disabled,
             id: "list_id_#{list.id}"
           ))
  end
end
