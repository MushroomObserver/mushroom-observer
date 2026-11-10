# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # `td`/`th` render only inside a `<table>`, so a hand-rolled
      # `td(class: "text-center")`/`th(class: "align-middle")` (the
      # row/body-mode escape hatch documented on Components::Table,
      # used when a column/table-level kwarg isn't available) should
      # use `Components::Table.align_class`/`.valign_class` instead
      # of hand-typing the utility class string, so the mapping has
      # one source of truth. Same resulting class string either way;
      # this just removes the hand-typed literal.
      #
      # For a raw `align-middle` class on `Table(...)` itself, see
      # MO/NoRawTableVariantClass. For one on a `.column(...)` call,
      # see MO/NoRawTableColumnAlignClass. This cop is for everything
      # else -- a hand-rolled `td`/`th` tag.
      #
      # @example
      #   # bad
      #   td(class: "text-center") { ... }
      #   th(class: "align-middle") { ... }
      #
      #   # good
      #   td(class: Components::Table.align_class(:center)) { ... }
      #   th(class: Components::Table.valign_class(:middle)) { ... }
      class NoRawTableCellAlignClass < Base
        include ClassKeywordPair

        MSG = "Don't pass `%<css_class>s` via class: -- use " \
              "`%<kwarg>s` instead."

        RESTRICT_ON_SEND = [:td, :th].freeze

        RAW_CLASS_TO_KWARG = {
          "text-center" => "Components::Table.align_class(:center)",
          "text-right" => "Components::Table.align_class(:right)",
          "align-middle" => "Components::Table.valign_class(:middle)"
        }.freeze

        def on_send(node)
          class_arg = class_keyword_value(node)
          return unless class_arg&.str_type?

          css_class = matching_class(class_arg.value)
          return unless css_class

          add_offense(node,
                      message: format(MSG, css_class: css_class,
                                           kwarg: RAW_CLASS_TO_KWARG[
                                             css_class
                                           ]))
        end

        private

        def class_keyword_value(node)
          hash = node.arguments.find(&:hash_type?)
          return nil unless hash

          pair = hash.pairs.find { |p| class_keyword_pair?(p) }
          pair&.value
        end

        def matching_class(class_string)
          tokens = class_string.to_s.split(/\s+/)
          RAW_CLASS_TO_KWARG.keys.find { |c| tokens.include?(c) }
        end
      end
    end
  end
end
