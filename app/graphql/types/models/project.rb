module Types::Models
  class Project < Types::BaseObject
    field :id, Integer, null: false
    field :user_id, Integer, null: false
    field :user, Types::Models::User, null: false
    field :admin_group_id, Integer, null: false
    field :admin_group, Types::Models::UserGroup, null: false
    field :user_group_id, Integer, null: false
    field :user_group, Types::Models::UserGroup, null: false
    field :title, String, null: false
    field :summary, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :rss_log_id, Integer, null: true
    field :rss_log, Types::Models::RssLog, null: true

    field :comments, [Types::Models::Comment], null: true
    field :interests, [Types::Models::Interest], null: true
    field :images, [Types::Models::Image], null: true
    field :observations, [Types::Models::Observation], null: true
    field :species_lists, [Types::Models::SpeciesList], null: true
  end
end
