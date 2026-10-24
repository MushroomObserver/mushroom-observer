# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # System/integration tests must not put `:not(...)` inside a
      # Capybara selector string -- it's an unreliable read under this
      # suite's Cuprite setup, confirmed on both class and attribute
      # negation, both single-element and multi-element waits (see
      # .claude/rules/system_test_state_polling.md). A test can find 0
      # matches for `".foo:not(.bar)"` at a 20s wait, every run, even
      # standalone with zero contention, while a direct
      # `document.querySelectorAll(...)` poll for the identical
      # condition passes immediately.
      #
      # Use the positive form instead: assert the positive selector
      # doesn't match, rather than asserting the negated selector does.
      #
      # @example
      #   # bad
      #   assert_selector(".foo:not(.bar)")
      #   assert_selector("input:not([disabled])")
      #   find(".foo:not(.bar)")
      #
      #   # good
      #   assert_no_selector(".foo.bar")
      #   assert_no_selector("input[disabled]")
      #   assert_no_selector(".foo.bar") # for find, assert first
      class NoNotPseudoSelector < Base
        MSG = "Don't put `:not(...)` in a Capybara selector string -- " \
              "it's unreliable under this suite's driver. Assert the " \
              "positive form doesn't match instead (assert_no_selector " \
              "on the non-negated selector) -- see " \
              ".claude/rules/system_test_state_polling.md."

        RESTRICT_ON_SEND = [
          :find, :all, :first, :within, :find_all,
          :assert_selector, :assert_no_selector, :refute_selector,
          :assert_css, :assert_no_css,
          :has_selector?, :has_no_selector?,
          :has_css?, :has_no_css?,
          :has_xpath?, :has_no_xpath?
        ].freeze

        def on_send(node)
          node.arguments.each do |arg|
            next unless selector_with_not?(arg)

            add_offense(arg)
          end
        end

        private

        def selector_with_not?(arg)
          case arg.type
          when :str
            arg.value.include?(":not(")
          when :dstr
            arg.children.any? do |child|
              child.str_type? && child.value.include?(":not(")
            end
          else
            false
          end
        end
      end
    end
  end
end
