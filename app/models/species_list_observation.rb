# frozen_string_literal: true

# Glue table between species_lists and observations.
class SpeciesListObservation < ApplicationRecord
  belongs_to :species_list
  belongs_to :observation
end
