# frozen_string_literal: true

# Right-side dropdown that appears next to the page title (the
# "Context Actions" menu). Rendered into `content_for(:context_nav)`
# by `add_context_nav(links)`.
#
# Takes the same `[text, url, args]` tuple shape MO's tab builders
# (`Tabs::*Helper`) already produce. The dispatch on `args[:button]`
# (`:post` / `:destroy` / `:put` / `:patch` / nil) chooses between
# `button_to`, the corresponding `CrudButton::*` subclass, or plain
# `link_to`; see `LinkRendering#render_crud_button_or_link`.
class Components::ContextNav::TopBar < Components::Base
  include Components::ContextNav::LinkRendering

  def initialize(links:)
    super()
    @links = links.compact
  end

  def view_template
    return if @links.empty?

    # Bootstrap 3: the dropdown wrapper has to be an `<li>` for
    # alignment with the surrounding nav structure.
    li(class: "dropdown d-inline-block") do
      render_dropdown_toggle
      render_dropdown_menu
    end
  end

  private

  def render_dropdown_toggle
    a(class: "dropdown-toggle", id: "context_nav_toggle",
      role: "button", data: { toggle: "dropdown" },
      aria: { haspopup: "true", expanded: "false" }) do
      span(data: { dropdown_current_target: "title" }) do
        plain(:app_context_actions.l)
      end
      span(class: "caret ml-2")
    end
  end

  def render_dropdown_menu
    ul(id: "context_nav", class: "dropdown-menu",
       aria: { labelledby: "context_nav_toggle" }) do
      @links.each { |link| li { render_link_item(link) } }
    end
  end

  # One link inside the dropdown menu. Mirrors the pre-Phlex
  # `context_nav_link` helper: merges args, strips the
  # `d-block` class on buttons (other links need it),
  # dispatches via `render_crud_button_or_link`.
  def render_link_item(link)
    str, url, args = link
    args ||= {}
    kwargs = merge_context_nav_link_args(args, {})
    if args[:button].present? && kwargs[:class].present?
      kwargs[:class] = kwargs[:class].gsub("d-block", "").strip
    end
    render_crud_button_or_link(str, url, args, kwargs.compact_blank)
  end
end
