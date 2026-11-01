# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags `query_attr`/`attribute` called on an explicit `Query`/
      # `Query::*` constant -- e.g. `Query::Observations.query_attr(...)`.
      # `query_attr` mutates the class's attribute-type registry, shared
      # by every caller in the process; calling it on a live Query
      # subclass outside that subclass's own class body corrupts the
      # class for every other test/request in the same worker process,
      # even after an `ensure` block tries to restore it.
      #
      # This shipped as a hard-to-diagnose flake: a test declared
      # `Query::Observations.query_attr(:projects, [Project],
      # param_alias: :project)`, then "restored" it in `ensure` with
      # `Query::Observations.query_attr(:projects, [Project])` (no
      # `param_alias:`) -- correct when the test was written, but once a
      # later PR gave `:projects` its own `param_alias:` declaration,
      # the `ensure` block permanently wiped it out for the rest of
      # that MiniTest worker process. Every project-filtered
      # observations index request in that worker silently returned
      # unfiltered results instead of erroring.
      #
      # Use `Class.new(Query::Observations) { query_attr(...) }` instead
      # -- an anonymous subclass gets its own attribute-type registry,
      # so the mutation stays scoped to the subclass and doesn't touch
      # the shared class.
      #
      # @example
      #   # bad
      #   Query::Observations.query_attr(:projects, [Project],
      #                                   param_alias: :project)
      #
      #   # good
      #   subclass = Class.new(Query::Observations) do
      #     query_attr(:projects, [Project], param_alias: :project)
      #   end
      class NoQuerySubclassMutation < Base
        MSG = "Don't call `%<method>s` on a Query class constant -- it " \
              "mutates shared state for every other test/request in " \
              "this process. Use `Class.new(Query::Whatever) { " \
              "%<method>s(...) }` instead."

        RESTRICT_ON_SEND = [:query_attr, :attribute].freeze

        def on_send(node)
          receiver = node.receiver
          return unless receiver&.const_type?
          return unless query_class_receiver?(receiver)

          add_offense(node, message: format(MSG, method: node.method_name))
        end

        private

        def query_class_receiver?(receiver)
          receiver.const_name.to_s.match?(/\AQuery(::|\z)/)
        end
      end
    end
  end
end
