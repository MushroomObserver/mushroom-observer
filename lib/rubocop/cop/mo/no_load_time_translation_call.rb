# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # A `.t`/`.l`/`.tl`/`.tp`/`.tpl`/`.ti` call (or direct `I18n.t`)
      # with no enclosing `def`, block, or lambda runs once, when the
      # surrounding class/module body loads -- not per request. Under
      # #4807's DB/Solid-Cache-backed I18n, whatever the backend
      # resolves at that instant is baked in for the life of the
      # process (frozen into a `validates message:`, a constant, a
      # class-level memoized value, ...); a later cache warm or
      # fixture load cannot repair it. Wrap the call in a block/lambda
      # so it resolves at use time instead.
      #
      # @example
      #   # bad
      #   validates :author, format: { message: :validate_author.t }
      #   LABELS = { a: :option_a.t }.freeze
      #
      #   # good
      #   validates :author, format: { message: ->(*) { :validate_author.t } }
      #   LABELS = { a: -> { :option_a.t } }.freeze
      class NoLoadTimeTranslationCall < Base
        MSG = "Translation call `%<source>s` runs at class-load time, " \
              "not per request -- wrap it in a block/lambda so it " \
              "resolves at use time instead (see #4807)."

        TRANSLATION_METHODS = [:t, :l, :tl, :tp, :tpl, :ti].freeze
        DEFERRING_ANCESTORS = [:def, :defs, :block, :numblock].freeze

        def on_send(node)
          return unless load_time_translation_call?(node)
          return if deferred?(node)

          add_offense(node, message: format(MSG, source: node.source))
        end

        private

        def load_time_translation_call?(node)
          symbol_translation_call?(node) || i18n_t_call?(node)
        end

        def symbol_translation_call?(node)
          TRANSLATION_METHODS.include?(node.method_name) &&
            node.receiver&.sym_type?
        end

        def i18n_t_call?(node)
          node.method_name == :t &&
            node.receiver&.const_type? &&
            node.receiver.const_name == "I18n"
        end

        def deferred?(node)
          node.each_ancestor(*DEFERRING_ANCESTORS).any?
        end
      end
    end
  end
end
