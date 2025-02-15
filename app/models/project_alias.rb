# frozen_string_literal: true

class ProjectAlias < AbstractModel
  belongs_to :target, polymorphic: true
  belongs_to :project

  validates :name, presence: true
  validates :name, uniqueness: { scope: :project_id }

  def location_id=(id)
    self.target_id = id
  end

  def location_id
    target_id
  end

  def user_id=(id)
    self.target_id = id
  end

  def user_id
    target_id
  end

  def target_type=(type)
    self[:target_type] = type.capitalize
  end
end
