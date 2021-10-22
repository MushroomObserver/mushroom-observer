module Types::Models
  class RssLog < Types::BaseObject
    field :id, Integer, null: false
    field :observation_id, Integer, null: true
    field :observation, Types::Models::Observation, null: true
    field :species_list_id, Integer, null: true
    field :species_list, Types::Models::SpeciesList, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :notes, String, null: true
    field :name_id, Integer, null: true
    field :name, Types::Models::Name, null: true
    field :location_id, Integer, null: true
    field :location, Types::Models::Location, null: true
    field :project_id, Integer, null: true
    field :project, Types::Models::Project, null: true
    field :glossary_term_id, Integer, null: true
    field :glossary_term, Types::Models::GlossaryTerm, null: true
    field :article_id, Integer, null: true
    field :article, Types::Models::Article, null: true
  end
end
