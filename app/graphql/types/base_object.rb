# frozen_string_literal: true

module Types
  class BaseObject < GraphQL::Schema::Object
    # include ActionPolicy::GraphQL::Behaviour
    # edge_type_class(Types::BaseEdge)
    # connection_type_class(Types::BaseConnection)
    field_class(Types::BaseField)
  end
end
