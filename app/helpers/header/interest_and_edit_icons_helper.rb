# frozen_string_literal: true

#  add_interest_icons(user, object) # add content_for(:interest_icons)
#
# Draw the cutesy eye icons in the upper right side of screen. Typical usage:
#
#   # At top of view:
#   <%
#     add_page_title("Page Title")
#     add_interest_icons(@user, @object)
#   %>
#
module Header
  module InterestAndEditIconsHelper
    # Edit and destroy icons for the show page title bar.
    # Only shows buttons the user has permission to use.
    def add_edit_icons(object, user)
      icons = []
      icons << tag.li { edit_button(target: object, icon: :edit) } if
        can_edit_object?(object, user)
      icons << tag.li { destroy_button(target: object, icon: :delete) } if
        can_destroy_object?(object, user)

      return if icons.empty?

      content_for(:edit_icons) { icons.safe_join }
    end

    # Interest icons for email alerts, for the show page title bar.
    def add_interest_icons(user, object)
      return unless user

      img1, img2, img3 = interest_links(user, object)

      content_for(:interest_icons) do
        tag.ul(class: "nav navbar-flex interest-eyes h4 my-0") do
          [
            tag.li { img1 },
            tag.li { img2 + img3 }
          ].safe_join
        end
      end
    end

    # Array of image links which user can click to control getting emails
    def interest_links(user, object)
      type = object.type_tag
      case user.interest_in(object)
      when :watching
        interest_links_when_watching(object, type)
      when :ignoring
        interest_links_when_ignoring(object, type)
      else
        interest_links_default(object, type)
      end
    end

    def interest_links_when_watching(object, type)
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

    def interest_links_when_ignoring(object, type)
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

    def interest_links_default(object, type)
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
      link_to(
        label,
        set_interest_path(id: object.id, type: object.class.name, state: state),
        data: { turbo_stream: true }
      )
    end

    # Create large icon image.
    def interest_icon_big(type, alt) # :nodoc:
      image_tag("#{type}2.png", alt: alt, class: "interest_big", title: alt)
    end

    # Create small icon image.
    def interest_icon_small(type, alt) # :nodoc:
      image_tag("#{type}3.png", alt: alt, class: "interest_small", title: alt)
    end

    private

    def can_edit_object?(object, user)
      in_admin_mode? || object.can_edit?(user)
    end

    def can_destroy_object?(object, user)
      return can_destroy_location?(object, user) if object.is_a?(Location)

      can_edit_object?(object, user)
    end

    def can_destroy_location?(location, user)
      return false unless location.destroyable?

      in_admin_mode? || location.user == user
    end
  end
end
