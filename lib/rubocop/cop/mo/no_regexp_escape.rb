# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # `Regexp.escape` is almost always a symptom of building a
      # throwaway regex just to express "this text contains that
      # literal substring" -- a plain `String#include?`/`==` says the
      # same thing directly, can't silently under-escape a forgotten
      # call site, and skips the regex compile entirely. For text
      # pulled from a Nokogiri selector in a test, extract it first
      # and compare with `assert_includes(extracted, value.as_displayed)`
      # instead of interpolating an escaped value into a `text:` regex.
      #
      # A handful of sites need a non-literal pattern (anchors,
      # wildcards, alternation, variable whitespace) around an
      # escaped literal piece -- those are the legitimate exception;
      # silence them with an inline `rubocop:disable`/`:enable` pair
      # explaining why escaping is load-bearing there, not a file
      # Exclude.
      #
      # @example
      #   # bad
      #   assert_match(/#{Regexp.escape(name)}/, body)
      #   assert_select(sel, text: /#{Regexp.escape(label)}/)
      #
      # @example
      #   # good
      #   assert_includes(body, name)
      #   assert_includes(css_select(sel).text.as_displayed,
      #                   label.as_displayed)
      class NoRegexpEscape < Base
        MSG = "Regexp.escape/.quote usually means a plain substring/" \
              "equality check would do -- use String#include?/== (or " \
              "assert_includes against pre-extracted, .as_displayed " \
              "text) instead of building a regex just to express " \
              "\"contains\". If this site needs a non-literal pattern " \
              "around the escaped piece, silence with an inline " \
              "rubocop:disable/:enable explaining why."

        # `Regexp.quote` is a documented exact alias of `Regexp.escape`
        # -- restricting on only one name would let the other sidestep
        # the cop.
        RESTRICT_ON_SEND = [:escape, :quote].freeze

        def on_send(node)
          receiver = node.receiver
          return unless receiver&.const_type? && receiver.const_name == "Regexp"

          add_offense(node)
        end
      end
    end
  end
end
