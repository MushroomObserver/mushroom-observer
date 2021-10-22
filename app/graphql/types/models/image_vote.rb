module Types::Models
  class ImageVote < Types::BaseObject
    field :id, Integer, null: false
    field :value, Integer, null: false
    field :anonymous, Boolean, null: false
    field :user_id, Integer, null: true
    field :user, Types::Models::User, null: true
    field :image_id, Integer, null: true
    field :image, Types::Models::Image, null: true
  end
end
