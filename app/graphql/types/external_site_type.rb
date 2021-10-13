module Types
  class ExternalSiteType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true
    field :project_id, Integer, null: true
    field :project, Types::ProjectType, null: true
  end
end
