# frozen_string_literal: true

class ProjectAlias < ApplicationRecord
  belongs_to :target, polymorphic: true
  belongs_to :project

  validates :name, presence: true

  def location_id=(id)
    self.target_id = id
  end

  def user_id=(id)
    self.target_id = id
  end

  def target_type=(type)
    self[:target_type] = type.capitalize
  end
end
