# frozen_string_literal: true

module Types
  class ConfigureConnection < GraphQL::Types::Relay::BaseConnection
    # Currently applied to Types::BaseObject
    # BaseConnection has these nullable configurations
    # and the nodes field by default, but you can change
    # these options if you want
    # edges_nullable(true)
    # edge_nullable(true)
    # node_nullable(true)
    # has_nodes_field(true)

    field :total_count, Integer, null: false

    def total_count
      object.items.size
    end
  end
end
