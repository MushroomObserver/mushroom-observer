# frozen_string_literal: true

# Helpers for a page's context-nav menu (formerly the "tabset links"
# / "action menu" / "page's right-side dropdown").
#
# Two entry points:
#
#   - `add_context_nav(links)` (most callers) — populates both
#     `content_for(:context_nav)` (top-bar dropdown) and
#     `content_for(:context_nav_mobile)` (mobile sidebar). The actual
#     markup lives in `Components::ContextNav::TopBar` and
#     `Components::ContextNav::Sidebar`; this helper just sets the
#     `content_for` blocks the layout reads.
#   - `context_nav_links(links)` (a few ERB callers — see
#     `users/show/_profile.erb`) — returns an array of pre-rendered
#     HTML strings for each link tuple, useful when the caller wants
#     to wrap them in their own (non-dropdown) layout.
#
# `add_context_nav` accepts any of:
#   - an `Array` of `[text, url, args]` tuples (the legacy shape;
#     `app/helpers/tabs/*_helper.rb` methods return this — same
#     shape as `Tab::Base#to_a`)
#   - a `Tab::Collection` (each yielded `Tab::Base` is converted
#     via `#to_a`)
#   - a single `Tab::Base` instance (wrapped as a one-element list)
# where `args[:button]` (`:post` / `:destroy` / `:put` / `:patch` /
# nil) chooses the HTML element.
module Header
  module ContextNavHelper
    def add_context_nav(links)
      links = normalize_context_nav_links(links)
      return unless links&.compact&.any?

      links = links.compact
      top_bar_html = render(Components::ContextNav::TopBar.new(links: links))
      sidebar_html = render(Components::ContextNav::Sidebar.new(links: links))
      content_for(:context_nav) { top_bar_html }
      content_for(:context_nav_mobile) { sidebar_html }
    end

    # Convert Tab::Base / Tab::Collection inputs to the legacy
    # `[text, url, args]` tuple array shape the rest of this helper
    # (and `Components::ContextNav::TopBar` / `Sidebar`) consume.
    # Pass-through for nil and Array (legacy callers unchanged).
    def normalize_context_nav_links(links)
      case links
      when nil then nil
      when ::Tab::Collection then links.map(&:to_a)
      when ::Tab::Base then [links.to_a]
      else links
      end
    end

    # Returns an array of pre-rendered HTML strings — one per link
    # tuple. Used by ERB callers that need the link conversion
    # without the dropdown / sidebar wrapper (e.g.
    # `users/show/_profile.erb` wraps each link in its own `<li>`
    # under a `list-unstyled` `<ul>`).
    def context_nav_links(links, extra_args = {})
      return [] unless links

      links.compact.map { |link| context_nav_link(link, extra_args) }
    end

    # Convert one `[text, url, args]` tuple into a Rails-helper HTML
    # string. The Phlex equivalent that EMITS into a Phlex buffer
    # lives in `Components::ContextNav::LinkRendering`.
    def context_nav_link(link, extra_args = {})
      str, url, args = link
      args ||= {}
      kwargs = merge_context_nav_link_args(args, extra_args)
      if args[:button].present? && kwargs[:class].present?
        kwargs[:class] = kwargs[:class].gsub("d-block", "").strip
      end
      crud_button_or_link(str, url, args, kwargs.compact_blank)
    end

    def merge_context_nav_link_args(args, extra_args)
      kwargs = args.except(:button, :target)
      kwargs[:class] = class_names(kwargs[:class], extra_args[:class])
      kwargs.merge(extra_args.except(:class))
    end

    # Helper-context dispatch — produces an HTML string (`SafeBuffer`)
    # for one link. Mirrors
    # `Components::ContextNav::LinkRendering#render_crud_button_or_link`,
    # which emits the same shape into a Phlex buffer.
    def crud_button_or_link(str, url, args, kwargs)
      case args[:button]
      when :post
        button_to(str, url, **kwargs)
      when :destroy
        # Context-nav destroy tabs render as plain `[ DESTROY ]`-style
        # text links — opt out of `CrudButton::Delete`'s default icon
        # AND button-frame via `icon: nil` + `btn: nil` (callers can
        # override either by passing the kwarg).
        destroy_button(name: str, target: args[:target] || url,
                       **kwargs.reverse_merge(icon: nil, btn: nil))
      when :put
        put_button(name: str, path: url, **kwargs)
      when :patch
        patch_button(name: str, path: url, **kwargs)
      else
        link_to(str, url, kwargs)
      end
    end
  end
end
