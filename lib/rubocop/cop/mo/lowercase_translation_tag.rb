# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Translation tag symbols must be lowercase.
      #
      # MO's i18n tags are always lowercase (see GH issue #4843) --
      # title-cased display goes through `Symbol#ti`, not a separate
      # ALL-CAPS twin tag. A Symbol literal receiver with an uppercase
      # letter, used with `.l`/`.t`/`.tl`/`.tp`/`.tpl`/`.ti`, either
      # references a tag that no longer exists (silently falls through
      # to a slow, uncached lookup instead of raising -- the exact bug
      # `:Votes.t` caused: 574 redundant `translation_strings` queries
      # on a single page load) or is stale copy-paste from before the
      # #4843 sweep.
      #
      # @example
      #   # bad
      #   :Votes.t
      #   :NOTES.l
      #
      #   # good
      #   :votes.ti
      #   :notes.l
      class LowercaseTranslationTag < Base
        MSG = "Translation tag symbols must be lowercase (found " \
              "`%<symbol>s`). Use `.ti` for a title-cased presentation " \
              "instead of an ALL-CAPS twin tag."

        RESTRICT_ON_SEND = [:l, :t, :tl, :tp, :tpl, :ti].freeze

        def on_send(node)
          receiver = node.receiver
          return unless receiver&.sym_type?

          symbol = receiver.value.to_s
          return if symbol == symbol.downcase

          add_offense(receiver, message: format(MSG, symbol: receiver.source))
        end
      end
    end
  end
end
