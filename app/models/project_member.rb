# frozen_string_literal: true

class ProjectMember < ApplicationRecord
  enum trust_level:
         {
           unused: 0,
           no_trust: 1,
           hidden_gps: 2,
           editing: 3
         }

  belongs_to :project
  belongs_to :user
end
