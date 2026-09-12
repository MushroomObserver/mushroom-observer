# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags `self.status = ...` written directly inside a method
      # whose name doesn't end in `_invalid` -- the
      # `render_new_view_invalid`/`render_edit_view_invalid` convention
      # (see .claude/rules/turbo_submit_forms.md, issue #5052) exists
      # specifically so a status-forcing re-render is ONE call, not a
      # `render(...)` call followed by a separate status-mutating
      # statement tacked on afterward. The two-statement form has
      # shipped as a real bug multiple times during the Turbo-submit
      # sweep -- forgetting the second line silently leaves the
      # response at a plain `200`, which hangs Turbo Drive on a
      # same-URL re-render with no error, no exception, no console
      # message.
      #
      # A method name ending in `_invalid` is accepted regardless of
      # whether it matches the two generic names exactly --
      # `render_index_view_invalid`, `reload_form_invalid`, etc. are
      # legitimate custom pairs for verbs `ApplicationController`
      # doesn't generically cover (see
      # `MO/RedundantRenderViewInvalid` for the two names it does).
      #
      # @example
      #   # bad
      #   def reload_name_form
      #     render_new_view(location: new_name_path)
      #     self.status = :unprocessable_content
      #   end
      #
      #   # good -- one call, status set in the same render
      #   def reload_name_form
      #     render_new_view_invalid(location: new_name_path)
      #   end
      #
      #   # good -- a custom-named *_invalid pair for a non-new/edit verb
      #   def render_index_view_invalid(**)
      #     render_index_view(**)
      #     self.status = :unprocessable_content
      #   end
      class SelfStatusOutsideInvalidMethod < Base
        MSG = "Don't hand-set `self.status =` here -- fold it into a " \
              "method whose name ends in `_invalid` (or call the " \
              "existing one) so the status change travels with the " \
              "render call, not as an easy-to-forget second statement. " \
              "See .claude/rules/turbo_submit_forms.md."

        RESTRICT_ON_SEND = [:status=].freeze

        def on_send(node)
          return unless node.receiver&.self_type?

          enclosing = node.each_ancestor(:def, :defs).first
          return unless enclosing
          return if enclosing.method_name.to_s.end_with?("_invalid")

          add_offense(node)
        end
      end
    end
  end
end
