# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags a controller method with `phlex` anywhere in its name as
      # a `render_`-prefixed qualifier -- `render_phlex_*`
      # (`render_phlex_show`, `render_phlex_edit`, ...) and `*_phlex`
      # (`render_new_phlex`, `render_edit_phlex`, `render_show_phlex`,
      # ...) alike. The whole app is Phlex now -- there is no ERB left
      # to disambiguate from -- so the qualifier carries no information
      # and just adds noise to a name that should read as what action
      # the method renders.
      #
      # The established convention is `render_<action>_view`:
      # `render_new_view`, `render_edit_view`, `render_show_view`,
      # `render_index_view`, etc. -- not just for new/edit.
      # `render_new_view`/`render_edit_view` specifically (each taking
      # `status: :ok, **render_opts` and forwarding to
      # `render(View.new(...), status: status, **render_opts)`) are
      # called BY THAT EXACT NAME from `ApplicationController`'s
      # generic `render_new_view_invalid`/`render_edit_view_invalid`
      # dispatchers (see .claude/rules/turbo_submit_forms.md, issue
      # #5052) -- a `render_phlex_edit`/`render_phlex_new` breaks that
      # dispatch silently, since the generic method calls
      # `render_edit_view`/`render_new_view` and falls through to
      # `ApplicationController`'s own base implementation instead of
      # the controller's intended one.
      #
      # @example
      #   # bad
      #   def render_phlex_edit(**render_opts)
      #     render(Views::Controllers::Foo::Edit.new(...), **render_opts)
      #   end
      #
      #   # good
      #   def render_edit_view(status: :ok, **render_opts)
      #     render(Views::Controllers::Foo::Edit.new(...),
      #            status: status, **render_opts)
      #   end
      #
      #   # bad
      #   def render_phlex_show
      #     render(Views::Controllers::Foo::Show.new(...))
      #   end
      #
      #   # bad
      #   def render_show_phlex
      #     render(Views::Controllers::Foo::Show.new(...))
      #   end
      #
      #   # good
      #   def render_show_view
      #     render(Views::Controllers::Foo::Show.new(...))
      #   end
      class NoRenderPhlexMethodName < Base
        MSG = "Don't name a method `%<name>s` -- the whole app is Phlex " \
              "now, so a `phlex` qualifier carries no information. Use " \
              "`render_<action>_view` instead (`render_new_view`, " \
              "`render_edit_view`, `render_show_view`, " \
              "`render_index_view`, ...) -- ApplicationController's " \
              "render_new_view_invalid/render_edit_view_invalid " \
              "dispatchers call the new/edit pair by that exact name."

        PHLEX_QUALIFIER_RE = /\Arender_phlex_|_phlex\z/

        def on_def(node)
          return unless PHLEX_QUALIFIER_RE.match?(node.method_name.to_s)

          add_offense(node, message: format(MSG, name: node.method_name))
        end
      end
    end
  end
end
