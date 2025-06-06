# frozen_string_literal: true

module SpeciesListsHelper
  def observation_count(species_list)
    tag.span("| #{species_list.observations.count} obs")
  end
end
