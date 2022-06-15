# frozen_string_literal: true

# Glue table between projects and observations.
class ProjectObservation < ApplicationRecord
  belongs_to :project
  belongs_to :observation
end
