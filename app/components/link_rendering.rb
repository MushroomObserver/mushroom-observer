# frozen_string_literal: true

# Shared link-rendering dispatcher: turns a `[text, url, args]`
# tuple into the right HTML element based on `args[:button]`
# (`:post` / `:destroy` / `:put` / `:patch` / nil-for-plain-link).
#
# Included by every component / view that needs to render a flat
# list of action-link tuples — currently `Components::Dropdown`
# (dropdown menus, including the top-nav context-nav and the
# sort-bar), `Views::Layouts::Sidebar::ContextNav` (mobile
# offcanvas), and `Views::Controllers::Users::Show::Profile`
# (action-links list).
#
# Tuples come from either `Tab::Base#to_a` (most callers) or a
# raw `[label, path, args]` build (e.g. `Views::Layouts::Header::
# Sorter#sort_tuple`). The dispatcher doesn't care which.
module Components::LinkRendering
  private

  # Strips MO-specific keys from the args hash and blends in any
  # extra_args' class. Returns a kwargs hash safe to splat into a
  # `link_to` / `button_to` / `CrudButton::*` call.
  def merge_context_nav_link_args(args, extra_args)
    mix(args.except(:button, :target), extra_args)
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
