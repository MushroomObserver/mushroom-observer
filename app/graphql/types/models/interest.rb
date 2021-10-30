module Types::Models
  class Interest < Types::BaseObject
    field :id, Integer, null: false
    field :target_type, String, null: true
    field :target_id, Integer, null: true
    field :user_id, Integer, null: true
    field :state, Boolean, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    # belongs to
    field :target, Types::Unions::InterestTarget, null: true
    field :user, Types::Models::User, null: true
  end
end
