# frozen_string_literal: true

# Species lists section of the observation form. Collapsible panel
# with species list checkboxes. Sub-component of
# `Views::Controllers::Observations::Form`.
#
# Wire shape: `observation[species_list_ids][]=<id>`. Checkedness
# defaults to `model.species_list_ids`; failure-reload uses
# `submitted_list_ids:` to preserve the user's choices without
# writing to the DB.
#
# @param form [Components::ApplicationForm] the parent form
# @param observation [Observation] the observation model
# @param lists [Array<SpeciesList>] available species lists
# @param submitted_list_ids [Array<String>, nil] user's just-
#   submitted species_list_ids on failure-reload; nil on normal
#   render.
class Views::Controllers::Observations::Form::Lists < Views::Base
  prop :form, _Any
  prop :observation, Observation
  prop :lists, _Array(SpeciesList)
  prop :submitted_list_ids, _Nilable(_Array(String)), default: nil

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
      expanded: any_checked?
    )
  end

  def any_checked?
    if @submitted_list_ids
      @submitted_list_ids.compact_blank.any?
    else
      @observation.species_list_ids.any?
    end
  end

  def render_body
    render_help_text
    render_list_checkboxes
  end

  def render_help_text
    p { :form_observations_list_help.t }
  end

  def render_list_checkboxes
    div(class: "overflow-scroll-checklist") do
      # Sentinel: ensures the key is always present in params even
      # when every checkbox is unchecked (Rack drops empty arrays).
      input(type: "hidden", name: "observation[species_list_ids][]",
            value: "", autocomplete: "off")
      @lists.each { |list| render_list_checkbox(list) }
    end
  end

  def render_list_checkbox(list)
    @form.checkbox_field(
      :species_list_ids,
      label: false,
      disabled: !permission?(list)
    ) do |cb|
      cb.option(list.id, checked: list_checked?(list.id)) do
        whitespace
        plain(list.title)
      end
    end
  end

  def list_checked?(list_id)
    if @submitted_list_ids
      @submitted_list_ids.map(&:to_i).include?(list_id.to_i)
    else
      @observation.species_list_ids.include?(list_id)
    end
  end
end
