# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Phlex `prop` declarations must not reference `ActiveRecord::
      # Relation` as (or within) the type -- a bare Relation carries no
      # element type, so Literal's construction-time check can't catch a
      # caller passing the wrong model's records (or the right model via
      # the wrong query). Materialize with `.to_a` at the call site and
      # declare `_Array(<Model>)` instead -- this doesn't drop whatever
      # `.includes`/`.joins` eager-loading is already on the relation,
      # it just changes when the query executes (immediately, instead
      # of on first enumeration).
      #
      # @example
      #   # bad
      #   prop :objects, ::ActiveRecord::Relation
      #   prop :objects, _Nilable(::ActiveRecord::Relation)
      #   prop :objects, _Union(_Array(::Foo), ::ActiveRecord::Relation)
      #
      #   # good
      #   prop :objects, _Array(::Foo)
      #   prop :objects, _Nilable(_Array(::Foo))
      class NoActiveRecordRelationProp < Base
        MSG = "Don't use ActiveRecord::Relation as a prop type -- it " \
              "carries no element type, so Literal can't catch a caller " \
              "passing the wrong model's records. Materialize with " \
              "`.to_a` at the call site and use `_Array(<Model>)` " \
              "instead."

        RESTRICT_ON_SEND = [:prop].freeze

        def on_send(node)
          type_arg = node.arguments[1]
          return unless type_arg
          return unless type_arg.source.include?("ActiveRecord::Relation")

          add_offense(type_arg)
        end
      end
    end
  end
end
