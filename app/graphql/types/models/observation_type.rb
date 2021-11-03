# frozen_string_literal = true

module Types::Models
  class ObservationType < Types::BaseObject
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :when, GraphQL::Types::ISO8601Date, null: true, resolver_method: :when_observed
    field :user_id, Integer, null: true
    field :specimen, Boolean, null: false
    field :notes, String, null: true
    field :thumb_image_id, Integer, null: true
    field :name_id, Integer, null: true
    field :location_id, Integer, null: true
    field :is_collection_location, Boolean, null: false
    field :vote_cache, Float, null: true
    field :num_views, Integer, null: false
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
    field :rss_log_id, Integer, null: true
    field :lat, Float, null: true
    field :long, Float, null: true
    field :where, String, null: true
    field :alt, Integer, null: true
    field :lifeform, String, null: true
    field :text_name, String, null: true
    field :classification, String, null: true
    field :gps_hidden, Boolean, null: false
    # belongs to
    field :location, Types::Models::LocationType, null: true
    field :name, Types::Models::NameType, null: true
    field :rss_log, Types::Models::RssLogType, null: true
    field :thumb_image, Types::Models::ImageType, null: true
    field :user, Types::Models::UserType, null: true
    # has many
    field :comments, [Types::Models::CommentType], null: true
    field :external_links, [Types::Models::ExternalLinkType], null: true
    field :interests, [Types::Models::InterestType], null: true
    field :namings, [Types::Models::NamingType], null: true
    field :observation_views, [Types::Models::ObservationViewType], null: true
    field :sequences, [Types::Models::SequenceType], null: true
    field :viewers, [Types::Models::UserType], null: true
    field :votes, [Types::Models::VoteType], null: true
    # has and belongs to many
    field :images, [Types::Models::ImageType], null: true
    field :projects, [Types::Models::ProjectType], null: true
    field :species_lists, [Types::Models::SpeciesListType], null: true
    field :collection_numbers, [Types::Models::CollectionNumberType], null: true
    field :herbarium_records, [Types::Models::HerbariumRecordType], null: true

    def user
      RecordLoader.for(User).load(object.user_id)
    end

    def name
      RecordLoader.for(Name).load(object.name_id)
    end

    def rss_log
      RecordLoader.for(RssLog).load(object.rss_log_id)
    end

    # custom fields
    field :img_src_thumb, String, null: true
    field :img_src_sm, String, null: true
    field :img_src_med, String, null: true
    field :img_src_lg, String, null: true
    field :img_src_huge, String, null: true
    field :img_src_full, String, null: true

    # field :format_name, String, null: true
    # field :detail, String, null: true

    def img_src_thumb
      Image.url(:thumbnail, object.thumb_image_id)
    end

    def img_src_sm
      Image.url(:small, object.thumb_image_id)
    end

    def img_src_med
      Image.url(:medium, object.thumb_image_id)
    end

    def img_src_lg
      Image.url(:large, object.thumb_image_id)
    end

    def img_src_huge
      Image.url(:huge, object.thumb_image_id)
    end

    def img_src_full
      Image.url(:full_size, object.thumb_image_id)
    end

    # def format_name
    #   RecordLoader.for(Name).load(object.name_id)
    #   object.format_name.
    #     delete_suffix(object.name.author).t
    # end

    # def detail
    #   RecordLoader.for(RssLog).load(object.rss_log_id)
    #   object.rss_log.detail
    # end
  end
end
