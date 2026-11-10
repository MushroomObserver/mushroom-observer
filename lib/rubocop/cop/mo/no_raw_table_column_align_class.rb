# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # `Table#column` (Components::Table) exposes `align:`/`valign:`
      # for the text-align/vertical-align classes it can emit itself
      # -- passing one of those classes via `class:`/`class!:` instead
      # skips the kwarg for no reason. Detects a `.column(...)` call
      # whose `class:` string contains one of those classes and
      # suggests the matching kwarg.
      #
      # For a raw `align-middle` class on `Table(...)` itself (not a
      # `.column(...)` call), see MO/NoRawTableVariantClass instead.
      #
      # @example
      #   # bad
      #   t.column(:name.t, class: "text-center")
      #   t.column(:name.t, class: "text-right")
      #   t.column(:name.t, class: "align-middle")
      #
      #   # good
      #   t.column(:name.t, align: :center)
      #   t.column(:name.t, align: :right)
      #   t.column(:name.t, valign: :middle)
      class NoRawTableColumnAlignClass < Base
        include ClassKeywordPair

        MSG = "Don't pass `%<css_class>s` via class: -- use " \
              "`%<kwarg>s` on .column(...) instead."

        RESTRICT_ON_SEND = [:column].freeze

        RAW_CLASS_TO_KWARG = {
          "text-center" => "align: :center",
          "text-right" => "align: :right",
          "align-middle" => "valign: :middle"
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
