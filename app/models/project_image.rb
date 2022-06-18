# frozen_string_literal: true

# Glue table between projects and images.
class ProjectImage < ApplicationRecord
  belongs_to :project
  belongs_to :image
end
