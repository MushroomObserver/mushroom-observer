module Types::Models
  class Observation < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :when, GraphQL::Types::ISO8601Date, null: true
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :specimen, Boolean, null: false
    field :notes, String, null: true
    field :thumb_image_id, Integer, null: true
    field :thumb_image, Types::Models::Image, null: true
    field :name_id, Integer, null: true
    field :name, Types::Models::Name, null: true
    field :location_id, Integer, null: true
    field :location, Types::Models::Location, null: true
    field :is_collection_location, Boolean, null: false
    field :vote_cache, Float, null: true
    field :num_views, Integer, null: false
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::Models::RssLog, null: true
    field :lat, Float, null: true
    field :long, Float, null: true
    field :where, String, null: true
    field :alt, Integer, null: true
    field :lifeform, String, null: true
    field :text_name, String, null: true
    field :classification, String, null: true
    field :gps_hidden, Boolean, null: false

    field :votes, [Types::Models::Vote], null: true
    field :comments, [Types::Models::Comment], null: true
    field :interests, [Types::Models::Interest], null: true
    field :sequences, [Types::Models::Sequence], null: true
    field :external_links, [Types::Models::ExternalLink], null: true
    field :namings, [Types::Models::Naming], null: true
    field :images, [Types::Models::Image], null: true
    field :projects, [Types::Models::Project], null: true
    field :species_lists, [Types::Models::SpeciesList], null: true
    field :collection_numbers, [Types::Models::CollectionNumber], null: true
    field :herbarium_records, [Types::Models::HerbariumRecord], null: true
    field :observation_views, [Types::Models::ObservationView], null: true
    field :viewers, [Types::Models::User], null: true
  end
end
