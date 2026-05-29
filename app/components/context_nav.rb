# frozen_string_literal: true

# Top-bar dropdown + mobile sidebar rendering for a page's context-nav
# (formerly `Header::ContextNavHelper#add_context_nav` + its rats' nest
# of private builder methods). Two Phlex components share the
# `[text, url, args]` tuple shape: `TopBar` builds the right-side
# dropdown that appears next to the page title, `Sidebar` builds the
# `xs`-only collapsible nav. The `add_context_nav(links)` helper is
# the entry point views (ERB + Phlex) call to populate both
# `content_for` blocks at once — see
# `app/helpers/header/context_nav_helper.rb`.
module Components::ContextNav
  # Shared link-rendering logic. Included by both `TopBar` and
  # `Sidebar`. Pulled out as a module so the two components don't
  # have to inherit from a common base just to share a few methods,
  # which would interfere with `Components::Base`'s Phlex wiring.
  module LinkRendering
    private

    # Strips MO-specific keys from the args hash and blends in any
    # extra_args' class. Returns a kwargs hash safe to splat into a
    # `link_to` / `button_to` / `CrudButton::*` call.
    def merge_context_nav_link_args(args, extra_args)
      kwargs = args.except(:button, :target)
      kwargs[:class] = class_names(kwargs[:class], extra_args[:class])
      kwargs.merge(extra_args.except(:class))
    end

    # Dispatch one `[text, url, args]` link tuple to the right HTML
    # element. Buttons go through the corresponding `CrudButton::*`
    # subclass; plain `link_to` is the default.
    def render_crud_button_or_link(str, url, args, kwargs)
      case args[:button]
      when :post
        button_to(str, url, **kwargs)
      when :destroy
        # Context-nav destroy tabs render as plain `[ DESTROY ]`-style
        # text links — opt out of `CrudButton::Delete`'s default icon
        # AND button-frame via `icon: nil` + `btn: nil` (callers can
        # override either by passing the kwarg).
        render(Components::CrudButton::Delete.new(
                 name: str, target: args[:target] || url,
                 **kwargs.reverse_merge(icon: nil, btn: nil)
               ))
      when :put
        render(Components::CrudButton::Put.new(
                 name: str, target: url, **kwargs
               ))
      when :patch
        render(Components::CrudButton::Patch.new(
                 name: str, target: url, **kwargs
               ))
      else
        link_to(str, url, kwargs)
      end
    end
  end
end
