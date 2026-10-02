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
  prop :form, ::Components::ApplicationForm
  prop :observation, Observation
  prop :lists, _Array(SpeciesList)
  prop :submitted_list_ids, _Nilable(_Array(String)), default: nil

  def view_template
    render(
      Components::Form::CheckboxPanel.new(
        form: @form,
        type: :species_list,
        form_object_name: "observation",
        objects: @lists,
        checked_ids: checked_list_ids,
        disabled_ids: disabled_list_ids,
        help_text: :form_observations_list_help.t
      )
    )
  end

  private

  def checked_list_ids
    if @submitted_list_ids
      @submitted_list_ids.compact_blank.map(&:to_i)
    else
      @observation.species_list_ids
    end
  end

  def disabled_list_ids
    @lists.reject { |list| permission?(list) }.map(&:id)
  end
end
