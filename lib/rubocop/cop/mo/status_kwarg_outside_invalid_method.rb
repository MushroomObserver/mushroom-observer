# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags `status: :unprocessable_content` (or the older Rails
      # alias, `:unprocessable_entity`) passed as a keyword argument to
      # any call (`render(...)`, `render_edit_view(...)`, a
      # controller's own render helper, etc.) written directly inside
      # a method whose name doesn't end in `_invalid`. Same
      # convention as `MO/SelfStatusOutsideInvalidMethod`
      # (`self.status = ...` outside a `*_invalid` method) -- this
      # cop exists because the kwarg form is a second way to hand-roll
      # the exact same anti-pattern that cop already bans, and it
      # isn't a `self.status = ...` assignment so the other cop's
      # pattern doesn't see it. See .claude/rules/turbo_submit_forms.md
      # and issue #5052 -- a status-forcing re-render is supposed to
      # be ONE call, through `render_new_view_invalid`/
      # `render_edit_view_invalid` (or a custom `*_invalid` pair),
      # not a hand-rolled `status:` kwarg tacked onto an otherwise
      # plain render call.
      #
      # Excludes a `status:` sitting alongside an `xml:`/`json:` key in
      # the same call (`render(json: obj.errors, status: ...)`) -- an
      # API response, not a Turbo Drive HTML re-render, so the
      # `_invalid` convention (built specifically around the same-URL
      # 200-hangs-the-browser Turbo Drive failure mode) doesn't apply.
      #
      # @example
      #   # bad
      #   def dispatch_commit
      #     render_edit_view(location: x, status: :unprocessable_content)
      #   end
      #
      #   # good -- one call, status set by the generic dispatcher
      #   def dispatch_commit
      #     render_edit_view_invalid(location: x)
      #   end
      #
      #   # good -- a custom-named *_invalid pair for a non-new/edit verb
      #   def render_index_view_invalid(**)
      #     render_index_view(**)
      #     self.status = :unprocessable_content
      #   end
      class StatusKwargOutsideInvalidMethod < Base
        MSG = "Don't pass `status: %<status>s` as a kwarg here -- fold " \
              "it into a method whose name ends in `_invalid` (or " \
              "call the existing " \
              "render_new_view_invalid/render_edit_view_invalid) so " \
              "the status change travels with the render call, not as " \
              "a hand-rolled kwarg a later edit can drop unnoticed. " \
              "See .claude/rules/turbo_submit_forms.md."

        def on_pair(node)
          return unless status_unprocessable_pair?(node)
          return if xml_or_json_response?(node)

          enclosing = node.each_ancestor(:def, :defs).first
          return unless enclosing
          return if enclosing.method_name.to_s.end_with?("_invalid")

          add_offense(node,
                      message: format(MSG, status: node.value.value.inspect))
        end

        private

        def status_unprocessable_pair?(node)
          node.key.sym_type? && node.key.value == :status &&
            node.value.sym_type? &&
            [:unprocessable_content, :unprocessable_entity].
              include?(node.value.value)
        end

        # `status:`'s sibling pairs in the same call -- `render(json:
        # obj.errors, status: ...)`'s `status:` and `json:` are both
        # direct children of the same kwargs hash.
        def xml_or_json_response?(node)
          hash = node.parent
          return false unless hash&.hash_type?

          hash.pairs.any? do |pair|
            pair.key.sym_type? && [:xml, :json].include?(pair.key.value)
          end
        end
      end
    end
  end
end
