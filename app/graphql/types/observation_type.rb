module Types
  class ObservationType < Types::BaseObject
    field :id, ID, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :when, GraphQL::Types::ISO8601Date, null: true
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: true
    field :specimen, Boolean, null: false
    field :notes, String, null: true
    field :thumb_image_id, Integer, null: true
    field :thumb_image, Types::ImageType, null: true
    field :name_id, Integer, null: true
    field :name, Types::NameType, null: true
    field :location_id, Integer, null: true
    field :location, Types::LocationType, null: true
    field :is_collection_location, Boolean, null: false
    field :vote_cache, Float, null: true
    field :num_views, Integer, null: false
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::RssLogType, null: true
    field :lat, Float, null: true
    field :long, Float, null: true
    field :where, String, null: true
    field :alt, Integer, null: true
    field :lifeform, String, null: true
    field :text_name, String, null: true
    field :classification, String, null: true
    field :gps_hidden, Boolean, null: false

    field :votes, [Types::VoteType], null: true
    field :comments, [Types::CommentType], null: true
    field :interests, [Types::InterestType], null: true
    field :sequences, [Types::SequenceType], null: true
    field :external_links, [Types::ExternalLinkType], null: true
    field :namings, [Types::NamingType], null: true
    field :images, [Types::ImageType], null: true
    field :projects, [Types::ProjectType], null: true
    field :species_lists, [Types::SpeciesListType], null: true
    field :collection_numbers, [Types::CollectionNumberType], null: true
    field :herbarium_records, [Types::HerbariumRecordType], null: true
    field :observation_views, [Types::ObservationViewType], null: true
    field :viewers, [Types::UserType], null: true
  end
end
