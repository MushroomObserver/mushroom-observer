# frozen_string_literal: true

# Glue table between projects and species_lists.
class ProjectSpeciesList < ApplicationRecord
  belongs_to :project
  belongs_to :species_list
end
