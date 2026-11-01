# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Shared by NoHandRolledColumnClass and NoRawBootstrapComponent:
      # is this hash pair node a `class:`/`class!:` attribute? Phlex's
      # `class!:` (see `mix` in phlex_reference.md) force-overrides
      # rather than merges, but it's still a class attribute -- a
      # hand-rolled Bootstrap class hiding behind `class!:` is just as
      # much a violation as one behind plain `class:`.
      module ClassKeywordPair
        CLASS_KEYS = [:class, :class!].freeze

        def class_keyword_pair?(pair)
          pair.pair_type? && pair.key.sym_type? &&
            CLASS_KEYS.include?(pair.key.value)
        end
      end
    end
  end
end
