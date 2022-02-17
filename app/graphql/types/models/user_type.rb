# frozen_string_literal: true

module Types::Models
  class UserType < Types::BaseObject
    implements Types::ImageUrls

    # NOTE: Rails: maybe migrate certain fields to non-nullable in the db
    field :id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :last_login, GraphQL::Types::ISO8601DateTime, null: true
    field :last_activity, GraphQL::Types::ISO8601DateTime, null: true
    field :verified, GraphQL::Types::ISO8601DateTime, null: true,
                                                      require_owner: true
    field :login, String, null: false
    field :name, String, null: true
    field :email, String, null: true, require_owner: true
    field :password, String, null: true, require_owner: true
    field :admin, Boolean, null: true, require_owner: true
    field :alert, String, null: true
    field :auth_code, String, null: true, require_admin: true
    field :mailing_address, String, null: true, require_owner: true
    field :notes, String, null: true
    field :notes_template, String, null: true, require_owner: true
    field :theme, String, null: true, require_owner: true
    field :thumbnail_size, Integer, null: true, require_owner: true
    field :image_size, Integer, null: true, require_owner: true
    field :default_rss_type, String, null: true, require_owner: true
    field :location_format, Integer, null: true, require_owner: true
    field :hide_authors, Integer, null: true, require_owner: true
    field :thumbnail_maps, Boolean, null: true, require_owner: true
    field :keep_filenames, Integer, null: true, require_owner: true
    field :layout_count, Integer, null: true, require_owner: true
    field :view_owner_id, Boolean, null: true, require_owner: true
    field :content_filter, String, null: true, require_owner: true
    field :license_id, Integer, null: false
    field :image_id, Integer, null: true, require_owner: true
    field :location_id, Integer, null: true, require_owner: true
    field :locale, String, null: true
    field :votes_anonymous, Integer, null: true, require_owner: true
    field :bonuses, String, null: true
    field :contribution, Integer, null: true
    field :email_comments_owner, Boolean, null: true, require_owner: true
    field :email_comments_response, Boolean, null: true, require_owner: true
    field :email_comments_all, Boolean, null: true, require_owner: true
    field :email_observations_consensus, Boolean, null: true,
                                                  require_owner: true
    field :email_observations_naming, Boolean, null: true, require_owner: true
    field :email_observations_all, Boolean, null: true, require_owner: true
    field :email_names_author, Boolean, null: true, require_owner: true
    field :email_names_editor, Boolean, null: true, require_owner: true
    field :email_names_reviewer, Boolean, null: true, require_owner: true
    field :email_names_all, Boolean, null: true, require_owner: true
    field :email_locations_author, Boolean, null: true, require_owner: true
    field :email_locations_editor, Boolean, null: true, require_owner: true
    field :email_locations_all, Boolean, null: true, require_owner: true
    field :email_general_feature, Boolean, null: true, require_owner: true
    field :email_general_commercial, Boolean, null: true, require_owner: true
    field :email_general_question, Boolean, null: true, require_owner: true
    field :email_html, Boolean, null: true, require_owner: true
    field :email_locations_admin, Boolean, null: true, require_owner: true
    field :email_names_admin, Boolean, null: true, require_owner: true

    # NOTE: uncomment each association as the models are added, OR...
    #
    # This post has examples that may help DRYing up association loading
    # https://www.keypup.io/blog/graphql-the-rails-way-part-1-exposing-your-resources-for-querying

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
  end
end
