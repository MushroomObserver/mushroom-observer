# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Phlex views/components must not hand-roll Bootstrap grid
      # column classes (`col-xs-6`, `col-sm-offset-4`, etc.) -- use
      # `Column(...)` (Components::Column) instead. Unlike
      # MO/NoRawBootstrapComponent, which matches a fixed set of
      # component root classes by exact string, grid classes are
      # parameterized by breakpoint and width, so this cop matches a
      # pattern instead of a fixed list.
      #
      # Detects a string literal, used as a `class:` value or a
      # `class_names(...)` argument, containing a `col-{breakpoint}-N`
      # or `col-{breakpoint}-offset-N` token. Only plain string
      # literals are checked -- an interpolated class string
      # (`"col-lg-#{n}"`) isn't caught.
      #
      # Scoped via this cop's Include/Exclude in .rubocop.yml -- the
      # Exclude list covers `Components::Column`'s implementation
      # file, which legitimately builds these classes to BE the
      # abstraction every other Phlex file is required to use
      # instead (same shape as MO/NoRawBootstrapComponent's exclusion
      # of the components it wraps), plus one documented "keep the
      # bug for visual parity" exception.
      #
      # @example
      #   # bad
      #   div(class: "col-xs-12 col-sm-6") { ... }
      #   div(class: class_names("col-lg-4", extra))
      #
      #   # good
      #   Column(xs: 12, sm: 6) { ... }
      #   Column(lg: 4, class: extra)
      class NoHandRolledColumnClass < Base
        MSG = "Don't hand-roll `.col-*` grid classes -- use `Column(...)` " \
              "(Components::Column) instead."

        COL_CLASS_PATTERN =
          /(?:^|\s)col-(?:xs|sm|md|lg|xl)(?:-offset)?-\d+(?:\s|$)/

        def on_str(node)
          return unless node.value.match?(COL_CLASS_PATTERN)
          return unless class_attribute_value?(node)

          add_offense(node)
        end

        private

        def class_attribute_value?(node)
          parent = node.parent
          return false unless parent

          class_keyword_pair?(parent) || class_names_argument?(parent)
        end

        def class_keyword_pair?(parent)
          parent.pair_type? && parent.key.sym_type? &&
            parent.key.value == :class
        end

        def class_names_argument?(parent)
          parent.send_type? && parent.method?(:class_names)
        end
      end
    end
  end
end
