# frozen_string_literal: true

# Join table between projects and observations the project admin has
# excluded from the project's Updates tab candidate list.
class ProjectExcludedObservation < ApplicationRecord
  belongs_to :project
  belongs_to :observation
end
