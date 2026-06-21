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
  # Maps `args[:button]` to the Button component class + any
  # per-type extra kwargs (e.g. `icon: nil` for destroy so context-
  # nav menus stay text-only).
  BUTTON_DISPATCH = {
    post: [Components::Button::Post, {}],
    destroy: [Components::Button::Delete, { icon: nil }],
    put: [Components::Button::Put, {}],
    patch: [Components::Button::Patch, {}]
  }.freeze

  private

  # Strips MO-specific keys from the args hash and blends in any
  # extra_args' class. Returns a kwargs hash safe to splat into a
  # `link_to` / `button_to` / `Button::*` call.
  def merge_context_nav_link_args(args, extra_args)
    mix(args.except(:button, :icon, :help, :target), extra_args)
  end

  # Dispatch one `[text, url, args]` link tuple to the right HTML
  # element. Mutation buttons go through the BUTTON_DISPATCH table;
  # plain `link_to` is the default for GET navigation links.
  def render_crud_button_or_link(str, url, args, kwargs)
    klass, extra = BUTTON_DISPATCH[args[:button]]
    return link_to(str, url, kwargs) unless klass

    render(klass.new(
             name: str,
             target: args[:target] || url,
             variant: :strip,
             **extra,
             **kwargs
           ))
  end
end
