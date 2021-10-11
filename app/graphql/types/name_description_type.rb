module Types
  class NameDescriptionType < Types::BaseObject
    field :id, ID, null: false
    field :version, Integer, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user_id, Integer, null: true
    field :name_id, Integer, null: true
    field :review_status, Integer, null: true
    field :last_review, GraphQL::Types::ISO8601DateTime, null: true
    field :reviewer_id, Integer, null: true
    field :ok_for_export, Boolean, null: false
    field :num_views, Integer, null: true
    field :last_view, GraphQL::Types::ISO8601DateTime, null: true
    field :source_type, Integer, null: true
    field :source_name, String, null: true
    field :locale, String, null: true
    field :public, Boolean, null: true
    field :license_id, Integer, null: true
    field :merge_source_id, Integer, null: true
    field :gen_desc, String, null: true
    field :diag_desc, String, null: true
    field :distribution, String, null: true
    field :habitat, String, null: true
    field :look_alikes, String, null: true
    field :uses, String, null: true
    field :notes, String, null: true
    field :refs, String, null: true
    field :classification, String, null: true
    field :project_id, Integer, null: true
  end
end
