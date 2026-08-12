# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Phlex views/components should call `Foo(...)` (Kit syntax)
      # rather than `render(Components::Foo.new(...))` when `Foo` sits
      # directly under `Components` -- Phlex::Kit generates a bare
      # instance method for every such class (see
      # .claude/rules/phlex_reference.md's "Kit syntax" section), so
      # the verbose `render(...)` form is never necessary for a
      # single-level Components class.
      #
      # Three real, already-encountered exceptions are detected and
      # skipped automatically (no `.rubocop.yml` file lists needed):
      #
      # 1. **Self-name collision**: a class named the same as the Kit
      #    method it would call (e.g. `Components::Matrix::Carousel`
      #    calling `Carousel(...)`, or a view class named `Table`
      #    calling `Table(...)`) breaks -- Kit's method resolution
      #    recurses into the caller's own class instead of resolving
      #    `Components::Carousel`/`Components::Table`. Confirmed by two
      #    existing bug-fix comments (commit 33fdc952e5).
      #    `render(Components::X.new(...))` is the correct, permanent
      #    form here, not a workaround to eventually remove.
      #
      # 2. **Mixin modules**: a `module Components::X` meant to be
      #    `include`d at varying nesting depths (e.g.
      #    `Components::IconWithText`, included by deeply-dispatched
      #    subclasses like `Components::Button::Edit`) can't reliably
      #    assume Kit sugar is mixed in that far down the ancestor
      #    chain. Any `render(...)` whose nearest enclosing definition
      #    is a bare `module` (not a `class`) is skipped.
      #
      # 3. **`ApplicationForm` subclasses**: `Components::ApplicationForm`
      #    is a class, not a module, so Phlex::Kit's `const_added` hook
      #    never fires for its subclasses (see phlex_reference.md's
      #    "Kit sugar doesn't reach app/components/application_form/*").
      #    A class whose direct superclass name ends in `ApplicationForm`
      #    is skipped.
      #
      # @example
      #   # bad
      #   render(Components::Alert.new(level: :info)) { ... }
      #
      #   # good
      #   Alert(level: :info) { ... }
      #
      #   # good -- self-name collision (exception 1 above)
      #   class Components::Matrix::Carousel < Components::Base
      #     def view_template
      #       render(Components::Carousel.new(...)) { ... }
      #     end
      #   end
      class PreferKitSyntax < Base
        MSG = "Use bare `%<name>s(...)` (Kit syntax) instead of " \
              "`render(Components::%<name>s.new(...))`."

        RESTRICT_ON_SEND = [:render].freeze

        def on_send(node)
          return unless bare_call?(node)

          ctor = component_constructor(node)
          return unless ctor

          name = single_level_components_class(ctor)
          return unless name
          return if inside_module?(node)
          return if application_form_subclass?(node)
          return if enclosing_class_named?(node, name)

          add_offense(node, message: format(MSG, name: name))
        end

        private

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

        def application_form_subclass?(node)
          class_node = node.each_ancestor(:class).first
          return false unless class_node

          superclass = class_node.children[1]
          return false unless superclass

          superclass.source.delete_prefix("::").end_with?("ApplicationForm")
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
