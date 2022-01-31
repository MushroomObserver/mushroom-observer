# frozen_string_literal: true

module Types::Models
  class CopyrightChangeType < Types::BaseObject
    field :id, Integer, null: false
    field :user_id, Integer, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :target_type, String, null: false
    field :target_id, Integer, null: false
    field :year, Integer, null: true
    field :name, String, null: true
    field :license_id, Integer, null: true
    # belongs to
    field :user, Types::Models::UserType, null: false
    field :license, Types::Models::LicenseType, null: true
  end
end
