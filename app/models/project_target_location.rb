# frozen_string_literal: true

# Glue table between projects and target locations.
class ProjectTargetLocation < ApplicationRecord
  belongs_to :project
  belongs_to :location
end
