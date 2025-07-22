# frozen_string_literal: true

#  Helpers for the top nav bar's context menu, formerly "tabset links".
#  Views should define the menu's content with an array of InternalLink.tabs

#  add_context_nav(links)      # add content_for(:context_nav)
#  context_nav_links(links)    # convert links -> link_to's / button_to's
#  nav_link(link)              # convert one link into an HTML link or button
#
module TitleContextNavHelper
  # Short-hand to render shared context_nav partial for a given set of links.
  # Called in the view, defines `:context_nav` which is rendered in layout.
  def add_context_nav(links)
    return unless links

    nav_links = context_nav_links(links)
    content_for(:context_nav) do
      context_nav_dropdown(title: "Actions", id: "context_nav",
                           links: nav_links)
    end
  end

  # Convert an array (of arrays) of link attributes into an array of HTML
  # that may be either links or CRUD button_to's, for RHS context nav menu
  # Example
  # links = [
  #   ["text", "url", { class: "edit_form_link" }],
  #   [nil, article, { button: :destroy }]
  # ]
  # context_nav_links(links) will make an array of the following HTML
  #   "<a href="url" class="edit_form_link">text</a>",
  #   "<form action='destroy'>" etc via destroy_button
  #   (The above array gives default button text and class)
  #
  # Allows passing an extra_args hash to be merged with each link's args
  #
  def context_nav_links(links, extra_args = {})
    return [] unless links

    links.compact.map do |link|
      context_nav_link(link, extra_args)
    end
  end

  # Unpacks the [text, url, args] array for a single link and figures out
  # which HTML to return for that type of link
  # Pass extra_args hash to modify the link/button attributes
  #
  def context_nav_link(link, extra_args = {})
    str, url, args = link
    args ||= {}
    kwargs = merge_context_nav_link_args(args, extra_args)
    # remove d-block from buttons, other links need it
    if args[:button].present? && kwargs[:class].present?
      kwargs[:class] = kwargs[:class].gsub("d-block", "").strip
    end

    crud_button_or_link(str, url, args, kwargs)
  end

  def crud_button_or_link(str, url, args, kwargs)
    case args[:button]
    when :destroy
      destroy_button(name: str, target: args[:target] || url, **kwargs)
    when :post
      post_button(name: str, path: url, **kwargs)
    when :put
      put_button(name: str, path: url, **kwargs)
    when :patch
      patch_button(name: str, path: url, **kwargs)
    else
      link_to(str, url, kwargs)
    end
  end

  # Make a hash of the kwargs that will be passed to link helper for HTML.
  # e.g. { data: { pileus: "awesome" }, id: "best_pileus", class: "hidden" }
  # Removes non-HTML args used by link_to/button helpers and merges with passed
  # extra_args, e.g. removes { name: "Click here to post", target: obs }
  # Note that class_names need to be concatenated, or the merge will overwrite.
  #
  def merge_context_nav_link_args(args, extra_args)
    kwargs = args&.except(:button, :target)
    # blend in the class names that may come from the extra_args
    kwargs[:class] = class_names(kwargs[:class], extra_args[:class])
    # merge in other args from extra_args (will overwrite keys!)
    kwargs&.merge(extra_args&.except(:class))
  end

  # rubocop:disable Metrics/AbcSize
  # The "dropdown-current" Stimulus controller should update the dropdown title
  # with the currently selected option on load, if show_current == true
  # For Bootstrap 3, this must be an <li> element for alignment
  def context_nav_dropdown(title: "", id: "", links: [])
    tag.li(class: "dropdown d-inline-block") do
      [
        tag.a(
          class: class_names(%w[dropdown-toggle]),
          id: "context_nav_toggle", role: "button",
          data: { toggle: "dropdown" },
          aria: { haspopup: "true", expanded: "false" }
        ) do
          concat(tag.span(title, data: { dropdown_current_target: "title" }))
          concat(tag.span(class: "caret ml-2"))
        end,
        tag.ul(
          id:, class: "dropdown-menu",
          aria: { labelledby: "context_nav_toggle" }
        ) do
          links.compact.each do |link|
            concat(tag.li(link))
          end
        end
      ].safe_join
    end
  end
  # rubocop:enable Metrics/AbcSize

  def search_nav_toggle
    tag.li(class: "d-inline-block navbar-form") do
      tag.button(
        link_icon(:search, title: :SEARCH.l),
        class: "btn btn-sm btn-outline-default",
        type: :button,
        data: { toggle: "collapse", target: "#search_nav" },
        aria: { expanded: "false", controls: "search_nav" }
      )
    end
  end
end
