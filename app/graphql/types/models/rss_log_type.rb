module Types::Models
  class RssLogType < Types::BaseObject
    field :id, Integer, null: false
    field :observation_id, Integer, null: true
    field :species_list_id, Integer, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :notes, String, null: true
    field :name_id, Integer, null: true
    field :location_id, Integer, null: true
    field :project_id, Integer, null: true
    field :glossary_term_id, Integer, null: true
    field :article_id, Integer, null: true
    # belongs to
    field :article, Types::Models::ArticleType, null: true
    field :glossary_term, Types::Models::GlossaryTermType, null: true
    field :location, Types::Models::LocationType, null: true
    field :name, Types::Models::NameType, null: true
    field :observation, Types::Models::ObservationType, null: true
    field :project, Types::Models::ProjectType, null: true
    field :species_list, Types::Models::SpeciesListType, null: true
  end
end
