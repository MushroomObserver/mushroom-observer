module Types
  class BaseConnection < Types::BaseObject
    # add `nodes` and `pageInfo` fields, as well as `edge_type(...)` and `node_nullable(...)` overrides
    # include GraphQL::Types::Relay::ConnectionBehaviors

    # BaseConnection has these nullable configurations
    # and the nodes field by default, but you can change
    # these options if you want
    # edges_nullable(true)
    # edge_nullable(true)
    # node_nullable(true)
    # has_nodes_field(true)

    # field :total_count, Integer, null: false

    # def total_count
    #   object.items.size
    # end
  end
end
