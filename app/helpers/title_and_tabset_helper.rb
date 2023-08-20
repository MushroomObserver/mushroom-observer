# frozen_string_literal: true

# --------- contextual nav ------------------------------------------------
#  --- links and buttons ----
#
#  title_tag_contents           # text to put in html header <title>
#  add_pager_for(object)        # add a prev/next pager for an object (show)
#  link_next                    # link to next object
#  link_prev                    # link to prev object
#  add_tab_set(links)           # add content_for(:tab_set)
#  create_links_to(links)       # convert links array -> link_to's / button_to's
#  create_link_to(link)         # convert one link attribute array into HTML
#  add_type_filters             # add content_for(:type_filters)
#  index_sorter                 # helper to render the sorter partial
#  add_interest_icons(user, object) #add content_for(:interest_icons)
#

module TitleAndTabsetHelper
  # contents of the <title> in html <head>
  def title_tag_contents(title:, action_name:)
    if title.present?
      title.strip_html.unescape_html # removes tags and special chars
    elsif TranslationString.where(tag: "title_for_#{action_name}").present?
      :"title_for_#{action_name}".t
    else
      action_name.tr("_", " ").titleize
    end
  end

  def add_pager_for(object)
    content_for(:prev_next_object) do
      render(partial: "application/content/prev_next_pager",
             locals: { object: object })
    end
  end

  # used by application/content/prev_next_pager
  # link to next object in query results
  def link_next(object)
    path = if object.type_tag == :rss_log
             send(:activity_log_path, object.id, flow: "next")
           else
             send("#{object.type_tag}_path", object.id, flow: "next")
           end
    link_with_query("#{:FORWARD.t} »", path)
  end

  # link to previous object in query results
  def link_prev(object)
    path = if object.type_tag == :rss_log
             send(:activity_log_path, object.id, flow: "prev")
           else
             send("#{object.type_tag}_path", object.id, flow: "prev")
           end
    link_with_query("« #{:BACK.t}", path)
  end

  # Short-hand to render shared tab_set partial for a given set of links.
  def add_tab_set(links)
    return unless links

    tabs = create_links_to(links)

    content_for(:tab_set) do
      render(partial: "application/content/tab_set", locals: { tabs: tabs })
    end
  end

  # Convert an array (of arrays) of link attributes into an array of HTML tabs
  # that may be either links or CRUD button_to's, for RHS tab set
  # Example
  # links = [
  #   ["text", "url", { class: "edit_form_link" }],
  #   [nil, article, { button: :destroy }]
  # ]
  # create_links_to(links) will make an array of the following HTML
  #   "<a href="url" class="edit_form_link">text</a>",
  #   "(an HTML form)" via destroy_button, gives default button text and class
  #
  def create_links_to(links)
    return [] unless links

    links.compact.map do |link|
      create_link_to(link)
    end
  end

  # Unpacks the [text, url, args] array for a single link and figures out
  # which HTML to return for that type of link
  def create_link_to(link)
    str, url, args = link
    args ||= {}
    kwargs = args&.except(:button, :target)
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

  # type_filters, currently only used in RssLogsController#index
  def add_type_filters
    content_for(:type_filters) do
      render(partial: "application/content/type_filters")
    end
  end

  # The "Everything" tab
  def filter_for_everything(types)
    label = :rss_all.t
    link = activity_logs_path(params: { type: :all })
    help = { title: :rss_all_help.t, class: "filter-only" }
    types == ["all"] ? label : link_with_query(label, link, **help)
  end

  # A single tab
  def filter_for_type(types, type)
    label = :"rss_one_#{type}".t
    link = activity_logs_path(params: { type: type })
    help = { title: :rss_one_help.t(type: type.to_sym), class: "filter-only" }
    types == [type] ? label : link_with_query(label, link, **help)
  end

  # Sort links, for indexes
  def add_sorter(query, links, link_all: false)
    content_for(:sorter) do
      if links && (query.num_results > 1)
        sorts = create_sorting_links(query, links, link_all)

        render(partial: "application/content/sorter", locals: { sorts: sorts })
      else
        ""
      end
    end
  end

  # Create sorting links, "graying-out" the current order.
  # Need query to know which is current order
  def create_sorting_links(query, links, link_all)
    results = []
    this_by = (query.params[:by] || query.default_order).sub(/^reverse_/, "")

    links.each do |by, label|
      results << link_or_grayed_text(link_all, this_by, label, query, by)
    end

    # Add a "reverse" button.
    results << sort_link(:sort_by_reverse.t, query, reverse_by(query, this_by))
  end

  def link_or_grayed_text(link_all, this_by, label, query, by)
    if !link_all && (by.to_s == this_by)
      [label.t, nil] # just text
    else
      sort_link(label.t, query, by)
    end
  end

  def sort_link(text, query, by)
    [text, { controller: query.model.show_controller,
             action: query.model.index_action,
             by: by }.merge(query_params)]
  end

  def reverse_by(query, this_by)
    if query.params[:by].to_s.start_with?("reverse_")
      this_by
    else
      "reverse_#{this_by}"
    end
  end

  # Draw the cutesy eye icons in the upper right side of screen.  It does it
  # by creating a "right" tab set.  Thus this must be called in the header of
  # the view and must not actually be rendered.  Typical usage would be:
  #
  #   # At top of view:
  #   <%
  #     # Specify the page's title.
  #     @title = "Page Title"
  #     add_interest_icons(@user, @object)
  #   %>
  #
  # This will cause the set of three icons to be rendered floating in the
  # top-right corner of the content portion of the page.

  def add_interest_icons(user, object)
    return unless user

    img1, img2, img3 = img_link_array(user, object)

    content_for(:interest_icons) do
      tag.div(img1 + safe_br + img2 + img3, class: "interest-eyes")
    end
  end

  # Array of image links which user can click to control getting email re object
  def img_link_array(user, object)
    type = object.type_tag
    case user.interest_in(object)
    when :watching
      img_links_when_watching(object, type)
    when :ignoring
      img_links_when_ignoring(object, type)
    else
      img_links_default(object, type)
    end
  end

  def img_links_when_watching(object, type)
    alt1 = :interest_watching.l(object: type.l)
    alt2 = :interest_default_help.l(object: type.l)
    alt3 = :interest_ignore_help.l(object: type.l)
    img1 = interest_icon_big("watch", alt1)
    img2 = interest_icon_small("halfopen", alt2)
    img3 = interest_icon_small("ignore", alt3)
    img2 = interest_link(img2, object, 0)
    img3 = interest_link(img3, object, -1)
    [img1, img2, img3]
  end

  def img_links_when_ignoring(object, type)
    alt1 = :interest_ignoring.l(object: type.l)
    alt2 = :interest_watch_help.l(object: type.l)
    alt3 = :interest_default_help.l(object: type.l)
    img1 = interest_icon_big("ignore", alt1)
    img2 = interest_icon_small("watch", alt2)
    img3 = interest_icon_small("halfopen", alt3)
    img2 = interest_link(img2, object, 1)
    img3 = interest_link(img3, object, 0)
    [img1, img2, img3]
  end

  def img_links_default(object, type)
    alt1 = :interest_watch_help.l(object: type.l)
    alt2 = :interest_ignore_help.l(object: type.l)
    img1 = interest_icon_small("watch", alt1)
    img2 = interest_icon_small("ignore", alt2)
    img1 = interest_link(img1, object, 1)
    img2 = interest_link(img2, object, -1)
    img3 = ""
    [img1, img2, img3]
  end

  # Create link to change interest state.
  def interest_link(label, object, state) # :nodoc:
    link_with_query(label, set_interest_path(id: object.id,
                                             type: object.class.name,
                                             state: state))
  end

  # Create large icon image.
  def interest_icon_big(type, alt) # :nodoc:
    image_tag("#{type}2.png", alt: alt, class: "interest_big", title: alt)
  end

  # Create small icon image.
  def interest_icon_small(type, alt) # :nodoc:
    image_tag("#{type}3.png", alt: alt, class: "interest_small", title: alt)
  end
end
