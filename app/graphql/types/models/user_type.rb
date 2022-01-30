# frozen_string_literal: true

module Types::Models
  class UserType < Types::BaseObject
    # TODO: Rails: maybe migrate certain fields to non-nullable in the db
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :last_login, GraphQL::Types::ISO8601DateTime, null: true
    field :last_activity, GraphQL::Types::ISO8601DateTime, null: true
    field :verified, GraphQL::Types::ISO8601DateTime, null: true
    field :login, String, null: false
    field :name, String, null: true
    field :email, String, null: false
    field :password, String, null: false
    field :admin, Boolean, null: true
    field :alert, String, null: true
    field :auth_code, String, null: true
    field :mailing_address, String, null: true
    field :notes, String, null: true
    field :notes_template, String, null: true
    field :theme, String, null: true
    field :thumbnail_size, Integer, null: true
    field :image_size, Integer, null: true
    field :default_rss_type, String, null: true
    field :location_format, Integer, null: true
    field :hide_authors, Integer, null: false
    field :thumbnail_maps, Boolean, null: false
    field :keep_filenames, Integer, null: false
    field :layout_count, Integer, null: true
    field :view_owner_id, Boolean, null: false
    field :content_filter, String, null: true
    field :license_id, Integer, null: false
    field :image_id, Integer, null: true
    field :location_id, Integer, null: true
    field :locale, String, null: true
    field :votes_anonymous, Integer, null: true
    field :bonuses, String, null: true
    field :contribution, Integer, null: true
    field :email_comments_owner, Boolean, null: false
    field :email_comments_response, Boolean, null: false
    field :email_comments_all, Boolean, null: false
    field :email_observations_consensus, Boolean, null: false
    field :email_observations_naming, Boolean, null: false
    field :email_observations_all, Boolean, null: false
    field :email_names_author, Boolean, null: false
    field :email_names_editor, Boolean, null: false
    field :email_names_reviewer, Boolean, null: false
    field :email_names_all, Boolean, null: false
    field :email_locations_author, Boolean, null: false
    field :email_locations_editor, Boolean, null: false
    field :email_locations_all, Boolean, null: false
    field :email_general_feature, Boolean, null: false
    field :email_general_commercial, Boolean, null: false
    field :email_general_question, Boolean, null: false
    field :email_html, Boolean, null: false
    field :email_locations_admin, Boolean, null: true
    field :email_names_admin, Boolean, null: true

    # TODO: uncomment each association as the models are added

    # belongs to
    # field :image, Types::Models::ImageType, null: true
    # field :license, Types::Models::LicenseType, null: false
    # field :location, Types::Models::LocationType, null: true

    # has many
    # field :api_keys, [Types::Models::ApiKeyType], null: true
    # field :comments, [Types::Models::CommentType], null: true
    # field :donations, [Types::Models::DonationType], null: true
    # field :external_links, [Types::Models::ExternalLinkType], null: true
    # field :images, [Types::Models::ImageType], null: true
    # field :interests, [Types::Models::InterestType], null: true
    # field :locations, [Types::Models::LocationType], null: true
    # field :location_descriptions, [Types::Models::LocationDescriptionType], 
    #                               null: true
    # field :names, [Types::Models::NameType], null: true
    # field :name_descriptions, [Types::Models::NameDescriptionType], null: true
    # field :namings, [Types::Models::NamingType], null: true
    # field :notifications, [Types::Models::NotificationType], null: true
    # field :observations, [Types::Models::ObservationType], null: true
    # field :projects_created, [Types::Models::ProjectType], null: true
    # field :publications, [Types::Models::PublicationType], null: true
    # # field :queued_emails, [Types::QueuedEmailType], null: true
    # field :sequences, [Types::Models::SequenceType], null: true
    # field :species_lists, [Types::Models::SpeciesListType], null: true
    # field :herbarium_records, [Types::Models::HerbariumRecordType], null: true
    # field :votes, [Types::Models::VoteType], null: true
    # field :reviewed_images, [Types::Models::ImageType], null: true
    # field :reviewed_name_descriptions, [Types::Models::NameDescriptionType], 
    #                                    null: true
    # # field :to_emails, [Types::Models::QueuedEmailType], null: true

    # has and belongs to many
    # field :user_groups, [Types::Models::UserGroupType], null: true
    # field :authored_names, [Types::Models::NameDescriptionType], null: true
    # field :edited_names, [Types::Models::NameDescriptionType], null: true
    # field :authored_locations, [Types::Models::LocationDescriptionType], 
    #                            null: true
    # field :edited_locations, [Types::Models::LocationDescriptionType], 
    #                          null: true
    # field :curated_herbaria, [Types::Models::HerbariumType], null: true

    # custom fields
    # field :img_src_thumb, String, null: true
    # field :img_src_sm, String, null: true
    # field :img_src_med, String, null: true
    # field :img_src_lg, String, null: true
    # field :img_src_huge, String, null: true
    # field :img_src_full, String, null: true

    # TODO: make a helper for img_src_xxxx, used in several models
    # urls are inconsistent, helper should prepend domain if missing
    # def img_src_thumb
    #   Image.url(:thumbnail, object.image_id)
    # end

    # def img_src_sm
    #   Image.url(:small, object.image_id)
    # end

    # def img_src_med
    #   Image.url(:medium, object.image_id)
    # end

    # def img_src_lg
    #   Image.url(:large, object.image_id)
    # end

    # def img_src_huge
    #   Image.url(:huge, object.image_id)
    # end

    # def img_src_full
    #   Image.url(:full_size, object.image_id)
    # end
  end
end
