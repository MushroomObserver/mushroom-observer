# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Phlex views should call `Foo(...)`, Kit syntax, rather than
      # `render(Components::Foo.new(...))` when `Foo` sits directly
      # under `Components`. Phlex::Kit generates a bare instance
      # method for every such class -- see
      # .claude/rules/phlex_reference.md's "Kit syntax" section. The
      # verbose `render(...)` form is not needed for a single-level
      # Components class.
      #
      # Two already-encountered exceptions are detected and skipped
      # automatically, without any `.rubocop.yml` file list.
      # `Components::ApplicationForm` subclasses are NOT an exception
      # -- Kit syntax reaches them fine, same as any other
      # `Components::Base` descendant.
      #
      # 1. **Self-name collision**: a class named the same as the Kit
      #    method it would call breaks -- Kit's method resolution
      #    recurses into the caller's own class instead of resolving
      #    the top-level Components class. `Components::Matrix::
      #    Carousel` calling `Carousel(...)`, and a view class named
      #    `Table` calling `Table(...)`, are both confirmed instances
      #    -- see commit 33fdc952e5. `render(Components::X.new(...))`
      #    is the correct, permanent form here, not a workaround to
      #    eventually remove.
      #
      # 2. **Mixin modules**: a `module Components::X` meant to be
      #    `include`d at varying nesting depths can't reliably assume
      #    Kit syntax is mixed in that far down the ancestor chain.
      #    `Components::IconWithText`, included by deeply-dispatched
      #    subclasses like `Components::Button::Edit`, is one such
      #    module. Any `render(...)` whose nearest enclosing
      #    definition is a bare `module`, not a `class`, is skipped.
      #
      # @example
      #   # bad
      #   render(Components::Alert.new(level: :info)) { ... }
      #
      #   # good
      #   Alert(level: :info) { ... }
      #
      #   # good -- self-name collision, exception 1 above
      #   class Components::Matrix::Carousel < Components::Base
      #     def view_template
      #       render(Components::Carousel.new(...)) { ... }
      #     end
      #   end
      class PreferKitSyntax < Base
        extend AutoCorrector

        MSG = "Use bare `%<name>s(...)` Kit syntax instead of " \
              "`render(Components::%<name>s.new(...))` for this " \
              "top-level Components class -- it reads more clearly."

        RESTRICT_ON_SEND = [:render].freeze

        def on_send(node)
          return unless bare_call?(node)

          ctor = component_constructor(node)
          return unless ctor

          name = single_level_components_class(ctor)
          return unless name
          return if inside_module?(node)
          return if enclosing_class_named?(node, name)

          add_offense(node, message: format(MSG, name: name)) do |corrector|
            autocorrect(corrector, node, ctor, name)
          end
        end

        private

        # Reuses the constructor's own parens when it has them --
        # `Components::Foo.new(a, b)` becomes `Foo(a, b)`, dropping
        # `render(` and the outer `)`. A parens-less `.new` call (e.g.
        # `Components::Foo.new a, b`) has no inner closer to reuse, so
        # the whole node is replaced with its arguments re-wrapped in
        # parens instead of being dropped.
        def autocorrect(corrector, node, ctor, name)
          if ctor.loc.begin
            corrector.replace(node.loc.selector.join(ctor.loc.selector), name)
            corrector.remove(node.loc.end)
          else
            args = ctor.arguments.map(&:source).join(", ")
            corrector.replace(node.source_range, "#{name}(#{args})")
          end
        end

        def bare_call?(node)
          node.receiver.nil? || node.receiver.self_type?
        end

        def component_constructor(node)
          arg = node.arguments.first
          return nil unless arg&.send_type? && arg.method?(:new)

          arg
        end

        def single_level_components_class(ctor_node)
          receiver = ctor_node.receiver
          return nil unless receiver&.const_type?

          full_name = receiver.const_name
          return nil unless full_name

          parts = full_name.delete_prefix("::").split("::")
          return nil unless parts.length == 2 && parts.first == "Components"

          parts.last
        end

        def inside_module?(node)
          enclosing = node.each_ancestor(:class, :module).first
          enclosing&.module_type? || false
        end

        def enclosing_class_named?(node, name)
          class_node = node.each_ancestor(:class).first
          return false unless class_node

          own_name = class_node.children[0]&.const_name
          return false unless own_name

          own_name.split("::").last == name
        end
      end
    end
  end
end
