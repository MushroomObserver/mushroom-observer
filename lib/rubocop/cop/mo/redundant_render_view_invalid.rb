# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags a controller (or concern) defining its own
      # `render_new_view_invalid`/`render_edit_view_invalid` --
      # `ApplicationController` already provides both generically
      # (`render_x_view(**); self.status = :unprocessable_content`), so
      # a local redefinition is either a byte-for-byte duplicate or an
      # attempt to smuggle extra behavior into a name a reader will
      # assume is plain boilerplate.
      #
      # If a render-on-failure path genuinely needs extra state (e.g.
      # threading resubmitted form values back into the re-rendered
      # form), pass it as a kwarg at the CALL site instead --
      # `render_new_view_invalid(submitted: reload_form_params)` --
      # since the generic version forwards `**` straight through to
      # `render_new_view`/`render_edit_view` unchanged. See
      # .claude/rules/turbo_submit_forms.md (issue #5052) -- this exact
      # redundant-override mistake shipped in several controllers
      # during that sweep before being caught and reverted.
      #
      # @example
      #   # bad
      #   def render_new_view_invalid(**)
      #     render_new_view(**)
      #     self.status = :unprocessable_content
      #   end
      #
      #   # good -- just call it; ApplicationController already defines it
      #   def create
      #     ...
      #     render_new_view_invalid
      #   end
      class RedundantRenderViewInvalid < Base
        MSG = "Don't redefine `%<name>s` -- ApplicationController " \
              "already provides it generically. Call it directly " \
              "(pass extra kwargs at the call site if the render needs " \
              "them, e.g. `%<name>s(submitted: reload_form_params)`)."

        GENERIC_METHOD_NAMES = [:render_new_view_invalid,
                                :render_edit_view_invalid].freeze

        def on_def(node)
          return unless GENERIC_METHOD_NAMES.include?(node.method_name)

          add_offense(node, message: format(MSG, name: node.method_name))
        end
        alias on_defs on_def
      end
    end
  end
end
