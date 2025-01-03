# frozen_string_literal: true

class ProjectMember < ApplicationRecord
  enum :trust_level, [:unused, :no_trust, :hidden_gps, :editing]

  belongs_to :project
  belongs_to :user
end
