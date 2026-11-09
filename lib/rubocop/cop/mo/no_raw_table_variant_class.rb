# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # `Table(...)` (Components::Table) exposes `variant:` to apply
      # Bootstrap table modifier classes -- passing the same class
      # via `class:`/`class!:` instead skips that kwarg for no
      # reason. Detects a `Table(...)` call whose `class:` string
      # contains one of Bootstrap's table modifier classes and
      # suggests `variant:` instead.
      #
      # @example
      #   # bad
      #   Table(@rows, class: "table-striped")
      #
      #   # good
      #   Table(@rows, variant: :striped)
      class NoRawTableVariantClass < Base
        include ClassKeywordPair

        MSG = "Don't pass `table-%<variant>s` via class: -- use " \
              "`variant: :%<variant>s` on Table(...) instead."

        RESTRICT_ON_SEND = [:Table].freeze

        # Bootstrap 3's table modifier classes (Components::Table's
        # `variant:` just emits "table-#{v}" for any symbol, but only
        # these are Bootstrap classes -- matching on an unrestricted
        # "table-*" pattern would also flag app-specific identifier
        # classes like "table-visual-model").
        TABLE_VARIANTS = %w[striped condensed hover bordered].freeze

        def on_send(node)
          class_arg = class_keyword_value(node)
          return unless class_arg&.str_type?

          variant = matching_variant(class_arg.value)
          return unless variant

          add_offense(node, message: format(MSG, variant: variant))
        end

        private

        def class_keyword_value(node)
          hash = node.arguments.find(&:hash_type?)
          return nil unless hash

          pair = hash.pairs.find { |p| class_keyword_pair?(p) }
          pair&.value
        end

        def matching_variant(class_string)
          tokens = class_string.to_s.split(/\s+/)
          TABLE_VARIANTS.find { |variant| tokens.include?("table-#{variant}") }
        end
      end
    end
  end
end
