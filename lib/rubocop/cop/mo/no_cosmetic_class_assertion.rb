# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # A test assertion must not pin a cosmetic Bootstrap class:
      # button chrome (`.btn`, `.btn-outline-*`, `.btn-sm`/`-lg`),
      # spacing (`.mt-3`, `.px-2`, `.m-0`, `.ml-auto`, `.mx-n2`),
      # color/paint (`.text-*` except `.text-nowrap`, which is layout
      # behavior; `.bg-*`; `.border-*` incl. bare `.border`;
      # `.rounded*`; `.shadow*`), type styling
      # (`.font-weight-*`, `.font-italic`), alignment (`.align-*`,
      # `.float-*`), or a plain layout/styling class
      # (`.list-unstyled`, `.hanging-indent`, `.tight-list`, bare
      # `.badge`) -- nor a bare `li` or heading (`h1`-`h6`) tag
      # selector, which couples the assertion to markup structure
      # instead of behavior. Which heading level a section uses is
      # not this codebase's contract. A component test asserts
      # behavior/contract, not paint or structure -- a Bootstrap
      # upgrade or a markup refactor changes these, and every test
      # pinning the old shape breaks for no functional reason. See
      # "Don't pin cosmetic CSS classes" in .claude/rules/testing.md.
      #
      # A styling-abstraction component (Panel/Modal/CrudButton/Well,
      # where the class output is the thing under test) is an
      # exception -- silence it with an inline
      # `rubocop:disable`/`:enable` pair, not an Exclude.
      #
      # @example
      #   # bad
      #   assert_html(html, "a.btn.btn-sm.btn-outline-default")
      #   assert_selector(".create-button.ml-3")
      #
      #   # good
      #   assert_html(html, "a[href='/foo']")
      #   assert_selector(".create-button.d-none")
      class NoCosmeticClassAssertion < Base
        MSG = "Cosmetic Bootstrap class asserted in a test (%<match>s) " \
              "-- assert behavior/contract, not paint. See 'Don't pin " \
              "cosmetic CSS classes' in .claude/rules/testing.md."

        RESTRICT_ON_SEND = [
          :assert_html, :assert_no_html, :assert_selector,
          :assert_no_selector, :assert_includes, :assert_not_includes
        ].freeze

        # `.d-none`/`[hidden]` are visibility state, not paint -- the
        # pattern below doesn't match them (no `d-` prefix, no `btn`/
        # `font`/`text`/`bg`/`border`/`rounded`/`shadow`/`align`/
        # `float` token), so they're fair game. `.text-nowrap` is the
        # same kind of exception -- it's layout behavior (the element
        # can't wrap across a line break), not paint. `.badge-id` is
        # also exempt (the negative lookahead excludes any hyphenated
        # `badge-*` class) -- it's MO's IDBadge hook, not bare
        # Bootstrap `.badge` chrome.
        CLASS_PATTERN = /
          \.btn(-[a-z]+)?\b
          | \.[mp][tblrxy]?-(n?\d+|auto)\b
          | \.font-(weight-[a-z]+|italic)\b
          | \.text-(?!nowrap\b)[a-z]+\b
          | \.bg-[a-z]+\b
          | \.border(-[a-z0-9]+)?\b
          | \.rounded(-[a-z0-9]+)?\b
          | \.shadow(-[a-z]+)?\b
          | \.align-[a-z-]+\b
          | \.float-[a-z]+\b
          | \.list-unstyled\b
          | \.hanging-indent\b
          | \.tight-list\b
          | \.badge\b(?!-)
        /x

        # Bare-tag tokens need checking against the CSS selector
        # argument specifically, not the whole call -- unlike
        # CLASS_PATTERN's dotted tokens, `li`/`h1`-`h6` are common
        # substrings of id values (`#h1`), attribute values
        # (`a[title='View li details']`), and plain assertion text
        # (`assert_includes`/`assert_not_includes` don't take a
        # selector). The lookbehind/lookahead further requires a
        # selector-boundary position so `#h1`/`.h1`-style id/class
        # references don't match even within the selector argument.
        TAG_PATTERN = /
          (?<![#.\[a-z0-9-])\b(?:li|h[1-6])\b(?![a-z0-9-])
        /xi

        SELECTOR_ARG_INDEX = {
          assert_html: 1, assert_no_html: 1,
          assert_selector: 0, assert_no_selector: 0
        }.freeze

        def on_send(node)
          match = CLASS_PATTERN.match(node.source) || tag_match(node)
          return unless match

          add_offense(node, message: format(MSG, match: match[0]))
        end

        private

        def tag_match(node)
          index = SELECTOR_ARG_INDEX[node.method_name]
          return unless index

          selector_arg = node.arguments[index]
          return unless selector_arg

          # Strip attribute-selector brackets first -- their quoted
          # values (`[title='View li details']`) are free text, not
          # a tag-selector position, regardless of what word they
          # contain.
          stripped = selector_arg.source.gsub(/\[[^\]]*\]/, "")
          TAG_PATTERN.match(stripped)
        end
      end
    end
  end
end
