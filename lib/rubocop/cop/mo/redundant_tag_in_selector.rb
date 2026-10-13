# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # A test selector must not qualify a class with a generic
      # wrapper tag (`span.thing`, `div.thing`, `p.thing`) when the
      # class alone already selects the element -- the tag is
      # superfluous, and pins an incidental implementation detail
      # (which element the content happens to live in) rather than
      # the behavioral contract under test.
      #
      # Deliberately blunt: flags every `span.`/`div.`/`p.` + class
      # combination in a selector string. The case where the tag
      # disambiguates two elements sharing one class is an exception
      # -- confirm with the user and silence with an inline
      # `rubocop:disable`/`:enable` pair, not an Exclude.
      #
      # @example
      #   # bad
      #   assert_html(html, "span.exif_lat")
      #   assert_selector("div.has-id-indicator")
      #
      #   # good
      #   assert_html(html, ".exif_lat")
      #   assert_selector(".has-id-indicator")
      class RedundantTagInSelector < Base
        MSG = "Superfluous tag, brittle selector (%<match>s) -- if " \
              "\"%<bare>s\" alone would select it, drop the tag. See " \
              ".claude/rules/testing.md."

        RESTRICT_ON_SEND = [
          :assert_html, :assert_no_html, :assert_selector,
          :assert_no_selector, :assert_includes, :assert_not_includes
        ].freeze

        # Negative lookbehind excludes `#p.foo` (an id literally named
        # "p", not the <p> tag) and `.span.foo`/word-char-preceded
        # cases -- `\b` alone sees a word boundary after `#`/`.` too.
        PATTERN = /(?<![#.\w])(span|div|p)(\.[a-zA-Z0-9_-]+)/

        def on_send(node)
          match = PATTERN.match(node.source)
          return unless match

          add_offense(node, message: format(MSG, match: match[0],
                                                 bare: match[2]))
        end
      end
    end
  end
end
