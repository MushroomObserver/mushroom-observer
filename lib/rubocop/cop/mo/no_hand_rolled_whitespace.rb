# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Phlex views/components must not hand-roll inter-element spacing
      # or the non-breaking-space entity inside a rendered string --
      # Phlex's `whitespace` primitive and MO's `nbsp` helper
      # (`Components::Base#nbsp`) cover these cases.
      #
      # Three shapes, all inside `plain(...)`:
      #
      #   - A string that's entirely whitespace (`plain(" ")`) -- use
      #     `whitespace` instead, as a sibling statement.
      #   - An interpolated string (`"#{x} "`, `" #{x}"`) whose static
      #     part touching the boundary is a bare space -- the space is
      #     faking a separator between two rendered pieces; use
      #     `whitespace` as a sibling statement instead of baking it
      #     into the string.
      #   - Any string containing the literal `&nbsp;` entity -- use
      #     `nbsp` instead, which builds it through `SafeBuffer` so it
      #     renders as a non-breaking space instead of literal visible
      #     text.
      #
      # A pure, non-interpolated literal like `plain(", ")` or
      # `plain(" | ")` is not flagged -- that's separator content (a
      # comma, a pipe), not a faked spacer, and carries none of the
      # `html_safe`-coercion risk interpolation does.
      #
      # Scoped via this cop's Include/Exclude in .rubocop.yml:
      # applies to app/components + app/views, excluding
      # app/components/base.rb, where `nbsp` is defined.
      #
      # @example
      #   # bad
      #   plain(" ")
      #   plain("#{count} more ")
      #   trusted_html("&nbsp;".html_safe)
      #
      #   # good
      #   whitespace
      #   plain("#{count} more")
      #   whitespace
      #   nbsp
      class NoHandRolledWhitespace < Base
        MSG_WHITESPACE_ONLY = "Use `whitespace` instead of `plain(%<arg>s)` " \
                               "-- Phlex has a primitive for a bare space."
        MSG_PADDED = "Move the %<side>s space out of this string and use " \
                     "`whitespace` as a sibling statement instead of " \
                     "baking a separator space into the string."
        MSG_NBSP = "Use `nbsp` instead of a literal `&nbsp;` -- it builds " \
                   "the entity through `SafeBuffer` so it renders as a " \
                   "non-breaking space instead of literal visible text."

        RESTRICT_ON_SEND = [:plain].freeze

        def on_send(node)
          return unless node.arguments.one?

          arg = node.first_argument
          case arg.type
          when :str
            check_whitespace_only(node, arg)
          when :dstr
            check_padded_dstr(node, arg)
          end
        end

        def on_str(node)
          return unless node.value.include?("&nbsp;")

          add_offense(node, message: MSG_NBSP)
        end

        private

        def check_whitespace_only(node, str_node)
          value = str_node.value
          return if value.empty?
          return unless value.match?(/\A[ \t]+\z/)

          add_offense(node,
                      message: format(MSG_WHITESPACE_ONLY,
                                      arg: str_node.source))
        end

        def check_padded_dstr(node, dstr_node)
          first_part = dstr_node.children.first
          last_part = dstr_node.children.last

          if first_part&.str_type? && first_part.value.start_with?(" ")
            add_offense(node, message: format(MSG_PADDED, side: "leading"))
          elsif last_part&.str_type? && last_part.value.end_with?(" ")
            add_offense(node, message: format(MSG_PADDED, side: "trailing"))
          end
        end
      end
    end
  end
end
