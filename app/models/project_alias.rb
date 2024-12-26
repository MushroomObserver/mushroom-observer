# frozen_string_literal: true

class ProjectAlias < ApplicationRecord
  belongs_to :target, polymorphic: true
  belongs_to :project

  validates :name, presence: true
end
