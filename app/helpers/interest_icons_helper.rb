# frozen_string_literal: true

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
#     draw_interest_icons(@object)
#   %>
#
# This will cause the set of three icons to be rendered floating in the
# top-right corner of the content portion of the page.
module InterestIconsHelper
  def draw_interest_icons(object)
    return unless @user

    type = object.type_tag
    img1, img2, img3 = img_link_array(object, type)
    interest_tab(img1, img2, img3)
  end

  # Array of image links which user can click to control getting email re object
  def img_link_array(object, type)
    case @user.interest_in(object)
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
    link_with_query(label, controller: :interest, action: :set_interest,
                           id: object.id, type: object.class.name,
                           state: state)
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
