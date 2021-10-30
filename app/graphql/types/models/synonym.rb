module Types::Models
  class Synonym < Types::BaseObject
    field :id, ID, null: false
    # has many
    field :names, [Types::Models::Name], null: true
  end
end
