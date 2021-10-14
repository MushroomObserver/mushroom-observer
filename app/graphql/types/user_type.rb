module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :login, String, null: false
    field :password, String, null: false
    field :email, String, null: false
    field :theme, String, null: true
    field :name, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :last_login, GraphQL::Types::ISO8601DateTime, null: true
    field :verified, GraphQL::Types::ISO8601DateTime, null: true
    field :license_id, Integer, null: false
    field :license, Types::LicenseType, null: false
    field :contribution, Integer, null: true
    field :location_id, Integer, null: true
    field :location, Types::LocationType, null: true
    field :image_id, Integer, null: true
    field :image, Types::ImageType, null: true
    field :locale, String, null: true
    field :bonuses, String, null: true
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
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :admin, Boolean, null: true
    field :alert, String, null: true
    field :email_locations_admin, Boolean, null: true
    field :email_names_admin, Boolean, null: true
    field :thumbnail_size, Integer, null: true
    field :image_size, Integer, null: true
    field :default_rss_type, String, null: true
    field :votes_anonymous, Integer, null: true
    field :location_format, Integer, null: true
    field :last_activity, GraphQL::Types::ISO8601DateTime, null: true
    field :hide_authors, Integer, null: false
    field :thumbnail_maps, Boolean, null: false
    field :auth_code, String, null: true
    field :keep_filenames, Integer, null: false
    field :notes, String, null: true
    field :mailing_address, String, null: true
    field :layout_count, Integer, null: true
    field :view_owner_id, Boolean, null: false
    field :view_owner, Types::UserType, null: false
    field :content_filter, String, null: true
    field :notes_template, String, null: true

    # Relationship fields has_many
    field :api_keys, [Types::ApiKeyType], null: true
    field :comments, [Types::CommentType], null: true
    field :donations, [Types::DonationType], null: true
    field :external_links, [Types::ExternalLinkType], null: true
    field :images, [Types::ImageType], null: true
    field :interests, [Types::InterestType], null: true
    field :locations, [Types::LocationType], null: true
    # field :location_descriptions, [Types::LocationDescriptionType], null: true
    field :names, [Types::NameType], null: true
    # field :name_descriptions, [Types::NameDescriptionType], null: true
    field :namings, [Types::NamingType], null: true
    field :notifications, [Types::NotificationType], null: true
    field :observations, [Types::ObservationType], null: true
    field :projects_created, [Types::ProjectType], null: true
    field :publications, [Types::PublicationType], null: true
    # field :queued_emails, [Types::QueuedEmailType], null: true
    field :sequences, [Types::SequenceType], null: true
    field :species_lists, [Types::SpeciesListType], null: true
    field :herbarium_records, [Types::HerbariumRecordType], null: true
    field :votes, [Types::VoteType], null: true
    field :reviewed_images, [Types::ImageType], null: true
    # field :reviewed_name_descriptions, [Types::NameDescriptionType], null: true
    # field :to_emails, [Types::QueuedEmailType], null: true
    field :user_groups, [Types::UserGroupType], null: true
    # field :authored_names, [Types::NameDescriptionType], null: true
    # field :edited_names, [Types::NameDescriptionType], null: true
    # field :authored_locations, [Types::LocationDescriptionType], null: true
    # field :edited_locations, [Types::LocationDescriptionType], null: true
    field :curated_herbaria, [Types::HerbariumType], null: true
  end
end
