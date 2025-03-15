# frozen_string_literal: true

#  Helpers for the `tabs`, which are `link attribute arrays`
#  for building nav links (in the context of a page)

#  add_tab_set(tabs)            # add content_for(:tab_set)
#  make_tab_links(tabs)         # convert tabs -> link_to's / button_to's
#  make_link_for_one_tab(tab)   # convert one tab into an HTML link or button
#
module TitleTabSetHelper
  # Short-hand to render shared tab_set partial for a given set of tabs.
  def add_tab_set(tabs)
    return unless tabs

    links = make_tab_links(tabs, { class: "d-block" })

    content_for(:tab_set) do
      render(partial: "application/content/tab_set", locals: { links: links })
    end
  end

  # Convert an array (of arrays) of link attributes into an array of HTML tabs
  # that may be either links or CRUD button_to's, for RHS tab set
  # Example
  # links = [
  #   ["text", "url", { class: "edit_form_link" }],
  #   [nil, article, { button: :destroy }]
  # ]
  # make_tab_links(links) will make an array of the following HTML
  #   "<a href="url" class="edit_form_link">text</a>",
  #   "<form action='destroy'>" etc via destroy_button
  #   (The above array gives default button text and class)
  #
  # Allows passing an extra_args hash to be merged with each link's args
  #
  def make_tab_links(tabs, extra_args = {})
    return [] unless tabs

    tabs.compact.map do |tab|
      make_one_tab_link(tab, extra_args)
    end
  end

  # Unpacks the [text, url, args] array for a single link and figures out
  # which HTML to return for that type of link
  # Pass extra_args hash to modify the link/button attributes
  #
  def make_one_tab_link(tab, extra_args = {})
    str, url, args = tab
    args ||= {}
    kwargs = merge_tab_args_with_extra_args(args, extra_args)
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
  def merge_tab_args_with_extra_args(args, extra_args)
    kwargs = args&.except(:button, :target)
    # blend in the class names that may come from the extra_args
    kwargs[:class] = class_names(kwargs[:class], extra_args[:class])
    # merge in other args from extra_args (will overwrite keys!)
    kwargs&.merge(extra_args&.except(:class))
  end

  # New style dropdown tabsets take array of tabs as hash of args,
  #   { name:, link:, class:, id:, etc. }
  #   not fully-formed `link_to` or `link_with_query`
  def add_dropdown_tab_set(tabs:, title: :LINKS.t)
    content_for(:dropdown_tab_set) do
      render(partial: "application/content/dropdown_tab_set",
             locals: { title: title, links: create_dropdown_links(tabs) })
    end
  end

  def create_dropdown_links(tabs)
    extra_args = {
      role: "menuitem",
      class: "dropdown-item"
    }
    make_tab_links(tabs, extra_args)
  end

  def dropdown_link_options(args = {})
    args&.except(:name, :link, :button, :class) # prolly delete name and link
  end
end
