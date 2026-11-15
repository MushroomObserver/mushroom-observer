# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Capybara's `assert_text`/`assert_no_text` must be scoped to a
      # specific element, not called on `page`/a `*_session` variable
      # (or bare, with no enclosing `within`) -- an unscoped call
      # searches the whole page, so a failure dumps the whole page's
      # visible text into the log. Same principle as
      # `MO/NoFullHtmlAssertion`, for Capybara integration/system
      # tests instead of controller tests.
      #
      # Scope with `find(selector).assert_text(...)` (store the found
      # element in a local first if asserting more than once), or
      # wrap a bare call in `within(selector) { assert_text(...) }`.
      # A call on any other receiver (a found element, a form, etc.)
      # is assumed already scoped.
      #
      # @example
      #   # bad
      #   assert_text("Some text")
      #   page.assert_text("Some text")
      #   mary_session.assert_text("Some text")
      #
      #   # good
      #   find("#title").assert_text("Some text")
      #   within("#title") { assert_text("Some text") }
      #   mary_session.find("#title").assert_text("Some text")
      class NoUnscopedAssertText < Base
        MSG = "`%<method>s` is called %<where>s here -- that searches " \
              "the whole page, so a failure dumps the whole page's text " \
              "into the log. Scope it to an element first " \
              "(`find(...).%<method>s(...)`) or wrap it in " \
              "`within(...) { %<method>s(...) }`."

        RESTRICT_ON_SEND = [:assert_text, :assert_no_text].freeze

        SESSION_LIKE = /(^session|_session)$/

        def on_send(node)
          if node.receiver
            check_receiver(node)
          else
            check_bare(node)
          end
        end

        private

        def check_receiver(node)
          return unless page_or_session?(node.receiver)

          where = "on `#{node.receiver.source}`"
          add_offense(node,
                      message: format(MSG, method: node.method_name,
                                           where: where))
        end

        def page_or_session?(receiver)
          return true if receiver.send_type? && receiver.method?(:page) &&
                         !receiver.receiver

          name = session_like_name(receiver)
          name && SESSION_LIKE.match?(name.to_s)
        end

        # A `send` node's `children.first` is the receiver it's
        # called on, not its method name -- `receiver.method_name`
        # is the accessor for that. An `lvar` node has no method
        # name; its single child is the variable name.
        def session_like_name(receiver)
          return receiver.method_name if receiver.send_type?
          return receiver.children.first if receiver.lvar_type?

          nil
        end

        def check_bare(node)
          return if node.each_ancestor(:block).any? do |blk|
            blk.send_node.method?(:within) ||
            blk.send_node.method?(:within_window)
          end

          add_offense(node, message: format(MSG, method: node.method_name,
                                                 where: "with no scope"))
        end
      end
    end
  end
end
