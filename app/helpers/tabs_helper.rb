# encoding: utf-8
module TabsHelper

  # Short-hand to render shared tab_set partial for a given set of links.
  def draw_tab_set(links)
    render(partial: "/shared/tab_set", locals: {links: links})
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
  #     draw_interest_icons(@object)
  #   %>
  #
  # This will cause the set of three icons to be rendered floating in the
  # top-right corner of the content portion of the page.
  #
  def draw_interest_icons(object)
    if @user
      type = object.type_tag

      # Create link to change interest state.
      def interest_link(label, object, state) # :nodoc:
        link_with_query(label,
          controller: :interest,
          action: :set_interest,
          id: object.id,
          type: object.class.name,
          state: state
        )
      end

      # Create large icon image.
      def interest_icon_big(type, alt) # :nodoc:
        image_tag("#{type}2.png",
          alt: alt,
          width: "50px",
          height: "50px",
          class: "interest_big",
          title: alt
        )
      end

      # Create small icon image.
      def interest_icon_small(type, alt) # :nodoc:
        image_tag("#{type}3.png",
          alt: alt,
          width: "23px",
          height: "23px",
          class: "interest_small",
          title: alt
        )
      end

      def interest_tab(img1, img2, img3)
        content_tag(:div, img1 + safe_br + img2 + img3, style: "position: absolute; top: 0;")
      end

      case @user.interest_in(object)
      when :watching
        alt1 = :interest_watching.l(object: type.l)
        alt2 = :interest_default_help.l(object: type.l)
        alt3 = :interest_ignore_help.l(object: type.l)
        img1 = interest_icon_big("watch", alt1)
        img2 = interest_icon_small("halfopen", alt2)
        img3 = interest_icon_small("ignore", alt3)
        img2 = interest_link(img2, object, 0)
        img3 = interest_link(img3, object, -1)

      when :ignoring
        alt1 = :interest_ignoring.l(object: type.l)
        alt2 = :interest_watch_help.l(object: type.l)
        alt3 = :interest_default_help.l(object: type.l)
        img1 = interest_icon_big("ignore", alt1)
        img2 = interest_icon_small("watch", alt2)
        img3 = interest_icon_small("halfopen", alt3)
        img2 = interest_link(img2, object, 1)
        img3 = interest_link(img3, object, 0)

      else
        alt1 = :interest_watch_help.l(object: type.l)
        alt2 = :interest_ignore_help.l(object: type.l)
        img1 = interest_icon_small("watch", alt1)
        img2 = interest_icon_small("ignore", alt2)
        img1 = interest_link(img1, object, 1)
        img2 = interest_link(img2, object, -1)
        img3 = ""
      end
      interest_tab(img1, img2, img3)
    end
  end
end
