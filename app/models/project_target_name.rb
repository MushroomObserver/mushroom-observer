# frozen_string_literal: true

# Glue table between projects and target names.
class ProjectTargetName < ApplicationRecord
  belongs_to :project
  belongs_to :name
end
