# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags `render(SomeClass.new(...))` repeated inline across two or
      # more sibling `test_*` methods in the same test class, instead of
      # going through a single private `render_x` helper -- see "Extract
      # DRY Render Helper" in .claude/rules/testing.md.
      #
      # Only counts direct `render(<Const>.new(...))` calls where the
      # receiver of `.new` is a constant AND `.new` takes at least one
      # argument. A call already routed through a local helper
      # (`render_form(...)`, `render(build_table(...))`,
      # `render(klass.new(...))` with `klass` a variable) never matches
      # this pattern, so files that already extracted a helper are silent
      # by construction -- this cop only needs to catch the case where no
      # helper exists yet. A bare `render(Page.new)` with no arguments is
      # excluded even when repeated: the whole point of extracting a
      # helper is to stop an argument list from drifting out of sync
      # across call sites, and a zero-argument constructor has no
      # argument list to drift -- extracting one there trades a
      # single-line duplicate for a 3-line method that saves nothing.
      #
      # @example
      #   # bad
      #   def test_one
      #     html = render(Components::Foo.new(bar: 1))
      #   end
      #
      #   def test_two
      #     html = render(Components::Foo.new(bar: 2))
      #   end
      #
      #   # good
      #   def test_one
      #     html = render_foo(bar: 1)
      #   end
      #
      #   def test_two
      #     html = render_foo(bar: 2)
      #   end
      #
      #   private
      #
      #   def render_foo(**opts)
      #     render(Components::Foo.new(**opts))
      #   end
      class DryTestRenderHelper < Base
        MSG = "Repeated `render(%<class>s.new(...))` across sibling " \
              "test methods -- extract a private `render_x` helper " \
              "instead (see 'Extract DRY Render Helper' in " \
              ".claude/rules/testing.md)."

        def on_class(class_node)
          test_defs = class_node.each_descendant(:def).select do |def_node|
            owned_by?(def_node, class_node) && test_method?(def_node)
          end
          return if test_defs.size < 2

          each_duplicate_render_group(test_defs) do |nodes|
            nodes.each { |node| add_offense(node, message: message_for(node)) }
          end
        end

        private

        # A `def` belongs to `class_node` only if `class_node` is its
        # NEAREST enclosing class/sclass -- excludes `def`s that live
        # inside a class nested within `class_node` (each_descendant
        # would otherwise also pick those up, double-counting them
        # under both the inner and outer class).
        def owned_by?(def_node, class_node)
          def_node.each_ancestor(:class, :sclass).first.equal?(class_node)
        end

        def test_method?(def_node)
          def_node.method_name.to_s.start_with?("test_")
        end

        def each_duplicate_render_group(test_defs)
          renders_by_class = Hash.new { |h, k| h[k] = [] }
          test_defs.each do |def_node|
            def_node.each_descendant(:send) do |send_node|
              next unless render_new_call?(send_node)

              key = send_node.first_argument.receiver.source
              renders_by_class[key] << send_node
            end
          end

          renders_by_class.each_value do |nodes|
            yield(nodes) if nodes.size > 1
          end
        end

        def render_new_call?(node)
          node.method?(:render) && node.receiver.nil? &&
            node.arguments.size == 1 && new_call_with_args?(node.first_argument)
        end

        # `SomeClass.new(...)` with a constant receiver and at least one
        # argument -- a bare `SomeClass.new` has nothing to consolidate.
        def new_call_with_args?(node)
          node.send_type? && node.method?(:new) &&
            node.receiver&.const_type? && node.arguments.any?
        end

        def message_for(node)
          format(MSG, class: node.first_argument.receiver.source)
        end
      end
    end
  end
end
