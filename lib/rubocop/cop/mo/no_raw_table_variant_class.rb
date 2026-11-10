# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # `Table(...)` (Components::Table) exposes `variant:` and
      # `align_middle:` for classes it can emit itself -- passing one
      # of those classes via `class:`/`class!:` instead skips the
      # kwarg for no reason. Detects a `Table(...)` call whose
      # `class:` string contains one of those classes and suggests
      # the matching kwarg.
      #
      # @example
      #   # bad
      #   Table(@rows, class: "table-striped")
      #   Table(@rows, class: "table-align-middle")
      #
      #   # good
      #   Table(@rows, variant: :striped)
      #   Table(@rows, align_middle: true)
      class NoRawTableVariantClass < Base
        include ClassKeywordPair

        MSG = "Don't pass `%<css_class>s` via class: -- use " \
              "`%<kwarg>s` on Table(...) instead."

        RESTRICT_ON_SEND = [:Table].freeze

        # Classes Components::Table can emit itself. Bootstrap 3's
        # table modifiers (variant: just emits "table-#{v}" for any
        # symbol, but only these are Bootstrap classes -- matching on
        # an unrestricted "table-*" pattern would also flag
        # app-specific identifier classes like "table-visual-model")
        # plus the table-wide vertical-align class
        # (app/assets/stylesheets/mo/_tables.scss).
        RAW_CLASS_TO_KWARG = {
          "table-striped" => "variant: :striped",
          "table-condensed" => "variant: :condensed",
          "table-hover" => "variant: :hover",
          "table-bordered" => "variant: :bordered",
          "table-align-middle" => "align_middle: true"
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
