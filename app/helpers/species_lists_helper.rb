# frozen_string_literal: true

# View Helpers for Observation Lists
module SpeciesListsHelper
  def species_list_remove_button(species_list:, observation:)
    put_button(
      name: :REMOVE.t,
      path: observation_species_list_path(
        id: observation.id,
        species_list_id: species_list.id,
        commit: "remove"
      ), data: { confirm: :are_you_sure.l }
    )
  end
end
