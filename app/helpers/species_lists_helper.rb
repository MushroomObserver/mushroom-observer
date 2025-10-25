# frozen_string_literal: true

# View Helpers for Observation Lists
module SpeciesListsHelper
  def species_list_remove_obs_button(species_list:, observation:)
    put_button(
      name: :REMOVE.t,
      path: observation_species_list_path(
        id: observation.id,
        species_list_id: species_list.id,
        commit: "remove"
      ), data: { confirm: :are_you_sure.l }
    )
  end

  def species_list_add_obs_button(species_list:, observation:)
    put_button(
      name: :ADD.t,
      path: observation_species_list_path(
        id: observation.id,
        species_list_id: species_list.id,
        commit: "add"
      )
    )
  end
end
