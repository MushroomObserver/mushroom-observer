# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # A test assertion must not pin a cosmetic Bootstrap class --
      # button chrome (`.btn`, `.btn-default`, `.btn-outline-*`,
      # `.btn-sm`/`-lg`/`-xs`), a spacing utility (`.mt-3`, `.px-2`,
      # `.m-0`, `.ml-auto`, `.mx-n2`), or a known paint class
      # (`.font-weight-*`, `.text-muted`). A component test asserts
      # behavior/contract, not paint -- a Bootstrap upgrade or a
      # designer's tweak renames these, and every test pinning the
      # old name breaks for no functional reason. See "Don't pin
      # cosmetic CSS classes" in .claude/rules/testing.md.
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
        # `font-weight`/`text-muted` token), so they're fair game.
        CLASS_PATTERN = /
          \.btn(-[a-z]+)?\b
          | \.[mp][tblrxy]?-(n?\d+|auto)\b
          | \.font-weight-[a-z]+\b
          | \.text-muted\b
        /x

        def on_send(node)
          match = CLASS_PATTERN.match(node.source)
          return unless match

          add_offense(node, message: format(MSG, match: match[0]))
        end
      end
    end
  end
end
