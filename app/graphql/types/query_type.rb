module Types
  class QueryType < Types::BaseObject
    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :user, resolver: Queries::User
    field :users, resolver: Queries::Users
    field :observation, resolver: Queries::Observation
    field :observations, resolver: Queries::Observations
    field :location, resolver: Queries::Location
    field :locations, resolver: Queries::Locations

    # TODO: remove me
    field :test_field, String, null: false,
                               description: "An example field added by the generator"
    def test_field
      "Hello World!"
    end
  end
end
