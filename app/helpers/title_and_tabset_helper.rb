# frozen_string_literal: true

# --------- contextual nav ------------------------------------------------
#  --- links and buttons ----
#
#  title_tag_contents           # text to put in html header <title>
#  link_next                    # link to next object
#  link_prev                    # link to prev object
#  create_links                 # convert links into list of tabs
#  add_tab_set
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

  def add_prev_next_pager(object)
    content_for(:prev_next_object) do
      render(partial: "application/content/prev_next_pager",
             locals: { object: object })
    end
  end

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

    tabs = create_tabs(links)

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
  # create_tabs(links) will make an array of the following HTML
  #   "<a href="url" class="edit_form_link">text</a>",
  #   "(an HTML form)" via destroy_button, gives default button text and class
  #
  def create_tabs(links)
    return [] unless links

    links.compact.map do |str, url, args|
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
  end

  def add_type_filters
    content_for(:type_filters) do
      render(partial: "application/content/type_filters")
    end
  end

  # @sorts is set by ApplicationController#show_index_count_results
  def index_sorter(sorts)
    return "" unless sorts

    render(partial: "application/content/sorter", locals: { sorts: sorts })
  end

  # Draw the cutesy eye icons in the upper right side of screen.  It does it
  # by creating a "right" tab set.  Thus this must be called in the header of
  # the view and must not actually be rendered.  Typical usage would be:
  #
  #   # At top of view:
  #   <%
  #     # Specify the page's title.
  #     @title = "Page Title"
  #
  #     # Define set of linked text tabs for top-left.
  #     new_tab_set do
  #       add_tab("Tab Label One", link: args, ...)
  #       add_tab("Tab Label Two", link: args, ...)
  #       ...
  #     end
  #
  #     # Draw interest icons in the top-right.
  #     add_interest_icons(@object)
  #   %>
  #
  # This will cause the set of three icons to be rendered floating in the
  # top-right corner of the content portion of the page.

  def add_interest_icons(user, object)
    return unless user

    content_for(:interest_icons) do
      img1, img2, img3 = img_link_array(user, object)
      interest_tab(img1, img2, img3)
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

  def interest_tab(img1, img2, img3)
    content_tag(:div, img1 + safe_br + img2 + img3, class: "interest-eyes")
  end
end
