# frozen_string_literal: true

module Types::Models
  class ExternalSiteType < Types::BaseObject
    field :id, Integer, null: false
    field :name, String, null: true
    field :project_id, Integer, null: true

    # belongs to
    field :project, Types::Models::ProjectType, null: true

    # has many
    field :external_links, [Types::Models::ExternalLinkType], null: true

    # has many through
    # field :observations, [Types::Models::ObservationType], null: true
  end
end
