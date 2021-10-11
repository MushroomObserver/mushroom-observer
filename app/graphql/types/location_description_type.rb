module Types
  class LocationDescriptionType < Types::BaseObject
    field :id, ID, null: false
    field :version, Integer, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :location_id, Integer, null: true
    field :num_views, Integer, null: true
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
    field :source_type, Integer, null: true
    field :source_name, String, null: true
    field :locale, String, null: true
    field :public, Boolean, null: true
    field :license_id, Integer, null: true
    field :merge_source_id, Integer, null: true
    field :gen_desc, String, null: true
    field :ecology, String, null: true
    field :species, String, null: true
    field :notes, String, null: true
    field :refs, String, null: true
    field :ok_for_export, Boolean, null: false
    field :project_id, Integer, null: true
  end
end
