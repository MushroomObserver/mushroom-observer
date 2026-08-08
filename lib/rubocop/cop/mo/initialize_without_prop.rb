# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags a class that defines `initialize` with hand-rolled
      # `@ivar = value` assignments but declares no Literal `prop` of
      # its own -- MO's Phlex convention is Literal props (see
      # .claude/rules/phlex_reference.md's "ALWAYS use concrete prop
      # types" section and the #5020 prop-conversion sweep), not
      # manually-assigned instance state.
      #
      # A class whose `initialize` does nothing but COMPUTE a value
      # and forward it via `super(...)` (no `@ivar =` of its own) is
      # the legitimate "hybrid pattern" for a prop whose default
      # depends on another prop's value -- see
      # Components::Link::Edit/New/Download for the canonical
      # example. That shape is intentionally NOT flagged; only a
      # class that assigns its own ivars by hand, bypassing props
      # entirely, is.
      #
      # @example
      #   # bad
      #   class Components::Foo < Components::Base
      #     def initialize(name:, path:)
      #       @name = name
      #       @path = path
      #     end
      #   end
      #
      #   # good
      #   class Components::Foo < Components::Base
      #     prop :name, String
      #     prop :path, String
      #   end
      #
      #   # good -- hybrid pattern, no ivars of its own, forwards to super
      #   class Components::Foo::Edit < Components::Foo
      #     def initialize(name: nil, target: nil, **opts)
      #       name ||= default_name(target)
      #       super(name: name, target: target, **opts)
      #     end
      #   end
      class InitializeWithoutProp < Base
        MSG = "`initialize` hand-assigns instance variables but this " \
              "class declares no `prop` of its own -- use Literal props " \
              "instead (see .claude/rules/phlex_reference.md)."

        def on_class(class_node)
          init_def = direct_initialize(class_node)
          return unless init_def
          return unless assigns_own_ivar?(init_def)
          return if declares_prop?(class_node)

          add_offense(init_def)
        end

        private

        def direct_initialize(class_node)
          class_node.each_descendant(:def).find do |def_node|
            def_node.method?(:initialize) && owned_by?(def_node, class_node)
          end
        end

        # A node belongs to `class_node` only if `class_node` is its
        # NEAREST enclosing class/sclass -- excludes a nested class's
        # own `initialize`/`prop` from being attributed to the outer
        # class.
        def owned_by?(node, class_node)
          node.each_ancestor(:class, :sclass).first.equal?(class_node)
        end

        def assigns_own_ivar?(def_node)
          def_node.each_descendant(:ivasgn).any?
        end

        def declares_prop?(class_node)
          class_node.each_descendant(:send).any? do |send_node|
            send_node.method?(:prop) && send_node.receiver.nil? &&
              owned_by?(send_node, class_node)
          end
        end
      end
    end
  end
end
