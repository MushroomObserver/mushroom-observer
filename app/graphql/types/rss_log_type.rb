module Types
  class RssLogType < Types::BaseObject
    field :id, ID, null: false
    field :observation_id, Integer, null: true
    field :observation, Types::ObservationType, null: true
    field :species_list_id, Integer, null: true
    field :species_list, Types::SpeciesListType, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :notes, String, null: true
    field :name_id, Integer, null: true
    field :name, Types::NameType, null: true
    field :location_id, Integer, null: true
    field :location, Types::LocationType, null: true
    field :project_id, Integer, null: true
    field :project, Types::ProjectType, null: true
    field :glossary_term_id, Integer, null: true
    field :glossary_term, Types::GlossaryType, null: true
    field :article_id, Integer, null: true
    field :article, Types::ArticleType, null: true
  end
end
