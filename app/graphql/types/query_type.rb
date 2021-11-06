# frozen_string_literal: true

require("graphql/batch")
require("loaders/record_loader")
require("search_object")
require("search_object/plugin/graphql")

module Types
  class QueryType < Types::BaseObject
    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :article, resolver: Queries::Article
    field :articles, resolver: Queries::Articles
    # field :collection_number, resolver: Queries::CollectionNumber
    # field :collection_numbers, resolver: Queries::CollectionNumbers
    # field :comment, resolver: Queries::Comment
    # field :comments, resolver: Resolvers::Comments
    # field :copyright_change, resolver: Queries::CopyrightChange
    # field :copyright_changes, resolver: Resolvers::CopyrightChanges
    # field :donation, resolver: Queries::Donation
    # field :donations, resolver: Resolvers::Donations
    # field :external_link, resolver: Queries::ExternalLink
    # field :external_links, resolver: Resolvers::ExternalLinks
    # field :external_site, resolver: Queries::ExternalSite
    # field :external_sites, resolver: Resolvers::ExternalSites
    # field :glossary_term, resolver: Queries::GlossaryTerm
    # field :glossary_terms, resolver: Resolvers::GlossaryTerms
    # field :herbarium_record, resolver: Queries::HerbariumRecord
    # field :herbarium_records, resolver: Resolvers::HerbariumRecords
    field :herbarium, resolver: Queries::Herbarium
    field :herbaria, Types::Models::HerbariumType.connection_type, null: true
    # field :image, resolver: Queries::Image
    # field :images, resolver: Resolvers::Images
    # field :interest, resolver: Queries::Interest
    # field :interests, resolver: Resolvers::Interests
    # field :language, resolver: Queries::Language
    # field :languages, resolver: Queries::Languages
    field :location, resolver: Queries::Location
    field :locations, resolver: Queries::Locations
    # field :name, resolver: Queries::Name
    # field :names, resolver: Resolvers::Names
    # field :naming, resolver: Queries::Naming
    # field :namings, resolver: Resolvers::Namings
    # field :notification, resolver: Queries::Notification
    # field :notifications, resolver: Resolvers::Notifications
    field :observation, resolver: Queries::Observation
    field :observations, Types::Models::ObservationType.connection_type, null: false, resolver: Resolvers::Observations
    # field :observation_view, resolver: Queries::ObservationView
    # field :observation_views, resolver: Resolvers::ObservationViews
    # field :project, resolver: Queries::Project
    # field :projects, resolver: Resolvers::Projects
    # field :publication, resolver: Queries::Publication
    # field :publications, resolver: Resolvers::Publications
    # field :rss_log, resolver: Queries::RssLog
    # field :rss_logs, resolver: Resolvers::RssLogs
    # field :sequence, resolver: Queries::Sequence
    # field :sequences, resolver: Resolvers::Sequences
    # field :species_list, resolver: Queries::SpeciesList
    # field :species_lists, resolver: Resolvers::SpeciesLists
    # field :translation_string, resolver: Queries::TranslationString
    # field :translation_strings, resolver: Resolvers::TranslationStrings
    # field :user_group, resolver: Queries::UserGroup
    # field :user_groups, resolver: Resolvers::UserGroups
    field :user, resolver: Queries::User
    field :users, Types::Models::UserType.connection_type, null: false, resolver: Queries::Users
    # field :vote, resolver: Queries::Vote
    # field :votes, resolver: Resolvers::Votes

    def herbaria(**_args)
      Herbarium.order("created_at DESC")
      # object.herbaria
    end

    # def users
    #   ::User.all
    # end

    # TODO: remove me
    field :test_field, String, null: false,
                               description: "An example field added by the generator",
                               resolver: Resolvers::TestField
    # def test_field
    #   "Hello World!"
    # end
  end
end
