# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Phlex views/components must not interpolate a trailing colon
      # onto a label string (`"#{text}:"`) -- use `append_colon(text)`
      # (`app/components/localization.rb`) instead.
      #
      # Plain string interpolation coerces an `html_safe` SafeBuffer
      # (e.g. a `.ti`/`.t` translation result carrying embedded
      # textile/acronym markup) back into an unsafe String, so the
      # surrounding render then escapes it. `append_colon`'s
      # `[text, ":"].safe_join` preserves the `html_safe` flag
      # correctly instead.
      #
      # Matches a colon at the end of the string, optionally followed
      # by trailing whitespace (`"#{x}:"`, `"#{x}: "`) -- a colon
      # followed by more text (`"#{x}: some note"`) is prose, not a
      # label suffix, and isn't flagged.
      #
      # Scoped via this cop's Include/Exclude in .rubocop.yml:
      # applies to app/components + app/views, excluding
      # app/components/localization.rb, where `append_colon` is
      # defined.
      #
      # @example
      #   # bad
      #   plain("#{label}:")
      #   plain("#{label}: ")
      #
      #   # good
      #   plain(append_colon(label))
      class NoHandRolledColonSuffix < Base
        MSG = "Use `append_colon(...)` instead of interpolating a " \
              "trailing colon -- plain string interpolation coerces " \
              "an `html_safe` value back into an unsafe String."

        def on_dstr(node)
          last_part = node.children.last
          return unless last_part&.str_type?
          return unless last_part.value.match?(/:[ \t]*\z/)

          add_offense(node)
        end
      end
    end
  end
end
