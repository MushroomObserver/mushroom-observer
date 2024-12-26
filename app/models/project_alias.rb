class ProjectAlias < ApplicationRecord
  belongs_to :target, polymorphic: true
  belongs_to :project
end
