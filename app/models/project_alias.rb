# frozen_string_literal: true

class ProjectAlias < AbstractModel
  belongs_to :target, polymorphic: true
  belongs_to :project

  validates :name, presence: true
  validates :name, uniqueness: { scope: :project_id }

  def target_type=(type)
    self[:target_type] = type.capitalize
  end
end
