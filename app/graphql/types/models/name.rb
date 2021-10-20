module Types::Models
  class Name < Types::BaseObject
    field :id, ID, null: false
    field :version, Integer, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :description_id, Integer, null: true
    # field :description, Types::Models::NameDescription, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::Models::RssLog, null: true
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
    field :synonym, Types::Models::Name, null: true
    field :correct_spelling_id, Integer, null: true
    field :correct_spelling, Types::Models::Name, null: true
    field :notes, String, null: true
    field :classification, String, null: true
    field :ok_for_export, Boolean, null: false
    field :author, String, null: true
    field :lifeform, String, null: false
    field :locked, Boolean, null: false
    field :icn_id, Integer, null: true

    # field :descriptions, [Types::Models::NameDescription], null: true
    # field :misspellings, [Types::Models::Name], null: true
    field :comments, [Types::Models::Comment], null: true
    field :interests, [Types::Models::Interest], null: true
    field :namings, [Types::Models::Naming], null: true
    field :observations, [Types::Models::Observation], null: true
  end
end
