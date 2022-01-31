# frozen_string_literal: true

module Types::Models
  class NameType < Types::BaseObject
    field :id, Integer, null: false
    field :version, Integer, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :description_id, Integer, null: true
    field :rss_log_id, Integer, null: true
    field :num_views, Integer, null: true
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
    field :rank, Integer, null: true
    field :text_name, String, null: true
    field :search_name, String, null: true
    field :display_name, String, null: true
    field :sort_name, String, null: true
    field :citation, String, null: true
    field :deprecated, Boolean, null: false
    field :synonym_id, Integer, null: true
    field :correct_spelling_id, Integer, null: true
    field :notes, String, null: true
    field :classification, String, null: true
    field :ok_for_export, Boolean, null: false
    field :author, String, null: true
    field :lifeform, String, null: false
    field :locked, Boolean, null: false
    field :icn_id, Integer, null: true

    # belongs to
    field :correct_spelling, Types::Models::NameType, null: true
    field :description, Types::Models::NameDescriptionType, null: true
    field :rss_log, Types::Models::RssLogType, null: true
    field :synonym, Types::Models::NameType, null: true
    field :user, Types::Models::UserType, null: true

    def correct_spelling
      RecordLoader.for(Name).load(object.correct_spelling_id)
    end

    def description
      RecordLoader.for(NameDescription).load(object.description_id)
    end

    def rss_log
      RecordLoader.for(RssLog).load(object.rss_log_id)
    end

    def synonym
      RecordLoader.for(Name).load(object.synonym_id)
    end

    def user
      RecordLoader.for(User).load(object.user_id)
    end

    # has many
    field :descriptions, [Types::Models::NameDescriptionType], null: true
    field :misspellings, [Types::Models::NameType], null: true
    field :comments, [Types::Models::CommentType], null: true
    field :interests, [Types::Models::InterestType], null: true
    field :namings, [Types::Models::NamingType], null: true
    field :observations, [Types::Models::ObservationType], null: true

    # custom fields
    field :format_name, String, null: true

    def format_name
      object.display_name.delete_suffix(object.author).t
    end
  end
end
