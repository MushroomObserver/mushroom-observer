# frozen_string_literal: true

module Types::Models
  class ImageVoteType < Types::BaseObject
    field :id, Integer, null: false
    field :value, Integer, null: false
    field :anonymous, Boolean, null: false
    field :user_id, Integer, null: true
    field :image_id, Integer, null: true
    
    # belongs to
    field :image, Types::Models::ImageType, null: true
    field :user, Types::Models::UserType, null: true
  end
end
