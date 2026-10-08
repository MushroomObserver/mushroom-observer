# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Test assertions must not search/compare against the raw
      # controller-test response body, or use `"body"` as a CSS
      # selector -- both match the entire rendered document, so a
      # failure dumps the whole page into the log, and the assertion
      # is fragile to whitespace/attribute-order drift that doesn't
      # change what's on the page. Use a scoped selector
      # (`assert_html`/`assert_no_html`/`assert_select` with a
      # specific CSS selector) instead. See "FORBIDDEN: assertions
      # against rendered HTML body" in .claude/rules/testing.md.
      #
      # Deliberately does NOT try to catch this by matching a local
      # variable's *name* (`html`, `body`, etc.) -- a name is trivial
      # to rename around, and plenty of legitimate small-fragment
      # renders in this codebase are also conventionally named `html`.
      # Both checks here key off something that can't be renamed away:
      # `@response` is always the controller-test response object, and
      # `"body"` is always the whole-document selector, regardless of
      # what variable holds the html string being searched.
      #
      # Aliasing `@response.body` to a local first doesn't dodge this
      # either (testing.md calls this out by name) -- when the
      # haystack is a bare local variable, this cop looks for an
      # assignment of that same name to `@response.body` anywhere
      # earlier in the enclosing method/block and flags the use if it
      # finds one.
      #
      # @example
      #   # bad
      #   assert_match(/<input name="foo"/, @response.body)
      #   assert_includes(@response.body, "some text")
      #   body = @response.body
      #   assert_match(/<input name="foo"/, body)
      #   assert_select("body", text: /something/)
      #   assert_html(html, "body", text: "something")
      #
      #   # good
      #   assert_select("input[name='foo']")
      #   assert_html(html, "#some_id", text: "some text")
      class NoFullHtmlAssertion < Base
        MSG_RESPONSE_BODY = "Don't %<method>s against `@response.body` -- " \
                             "that's the full rendered HTML. Use a scoped " \
                             "selector (assert_html/assert_select) " \
                             "instead; see 'FORBIDDEN: assertions against " \
                             "rendered HTML body' in .claude/rules/testing.md."
        MSG_BODY_SELECTOR = 'Don\'t use "body" as the selector in ' \
                             "%<method>s -- it matches the whole " \
                             "document, same as matching the raw string " \
                             "directly. Use a specific selector instead."

        RESTRICT_ON_SEND = [
          :assert_match, :assert_no_match, :assert_includes,
          :assert_select, :assert_html, :assert_no_html
        ].freeze

        def on_send(node)
          case node.method_name
          when :assert_match, :assert_no_match
            check_response_body(node, node.arguments[1])
          when :assert_includes
            check_response_body(node, node.arguments[0])
          when :assert_select, :assert_html, :assert_no_html
            check_body_selector(node)
          end
        end

        private

        def check_response_body(node, haystack)
          return unless haystack && full_response_body?(haystack)

          add_offense(node,
                      message: format(MSG_RESPONSE_BODY,
                                      method: node.method_name))
        end

        def full_response_body?(node)
          response_body_node?(node) ||
            (node.lvar_type? && lvar_aliases_response_body?(node))
        end

        # `@response.body` -- the raw controller-test response string.
        # `node` is nil for an `lvasgn` inside a multiple-assignment's
        # `mlhs` (e.g. `a, b = 1, 2`), which carries no value -- the
        # value lives on the enclosing `masgn` instead.
        def response_body_node?(node)
          return false unless node

          node.send_type? && node.method?(:body) &&
            node.receiver&.ivar_type? &&
            node.receiver.children.first == :@response
        end

        # `body = @response.body` earlier in the same method/block,
        # then `assert_match(..., body)` -- an alias is still the
        # same string.
        def lvar_aliases_response_body?(lvar_node)
          name = lvar_node.children.first
          scope = lvar_node.each_ancestor(:def, :defs, :block).first
          return false unless scope

          scope.each_descendant(:lvasgn).any? do |asgn|
            asgn.children.first == name &&
              response_body_node?(asgn.children[1])
          end
        end

        def check_body_selector(node)
          selector_index = node.method?(:assert_select) ? 0 : 1
          selector = node.arguments[selector_index]
          return unless selector&.str_type? && selector.value == "body"

          add_offense(node,
                      message: format(MSG_BODY_SELECTOR,
                                      method: node.method_name))
        end
      end
    end
  end
end
