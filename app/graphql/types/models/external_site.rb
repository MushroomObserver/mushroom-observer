module Types::Models
  class ExternalSite < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true
    field :project_id, Integer, null: true
    field :project, Types::Models::Project, null: true
  end
end
