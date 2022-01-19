module Types::Models
  class SynonymType < Types::BaseObject
    field :id, ID, null: false
    # has many
    field :names, [Types::Models::NameType], null: true
  end
end
