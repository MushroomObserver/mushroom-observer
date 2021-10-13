module Types
  class ImageVoteType < Types::BaseObject
    field :id, ID, null: false
    field :value, Integer, null: false
    field :anonymous, Boolean, null: false
    field :user_id, Integer, null: true
    field :user, Types::UserType, null: false
    field :image_id, Integer, null: true
    field :image, Types::ImageType, null: false
  end
end
