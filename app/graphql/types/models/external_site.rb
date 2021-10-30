module Types::Models
  class ExternalSite < Types::BaseObject
    field :id, Integer, null: false
    field :name, String, null: true
    field :project_id, Integer, null: true
    # belongs to
    field :project, Types::Models::Project, null: true
    # has many
    field :external_links, [Types::Models::ExternalLink], null: true
    # has many through
    # field :observations, [Types::Models::Observation], null: true
  end
end
