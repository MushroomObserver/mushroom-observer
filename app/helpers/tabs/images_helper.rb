# frozen_string_literal: true

# html used in tabsets
module Tabs
  module ImagesHelper
    # link attribute arrays
    def images_index_tabs(query)
      # Add "show observations" link if this query can be coerced into an
      # observation query. (coerced_query_link returns array)
      [coerced_query_link(query, Observation)]
    end

    # assemble HTML for "tabset" for show_image
    # actually a list of links and the interest icons
    def show_image_tabset(image:)
      tabs = [
        show_image_obs_links(image),
        eol_link(image),
        edit_and_destroy_links(image),
        email_commercial_inquiry_link(image)
      ].flatten.reject(&:empty?)
      { pager_for: image, right: draw_tab_set(tabs) }
    end

    private

    def show_image_obs_links(image)
      return unless image.observations.length == 1

      obs = image.observations.first
      [
        link_with_query(:show_object.t(type: :observation),
                        permanent_observation_path(obs.id)),
        link_with_query(:show_object.t(type: :name),
                        name_path(obs.name.id)),
        link_to(:google_images.t,
                "http://images.google.com/images?q=#{obs.name.search_name}",
                target: "_blank", rel: "noopener")
      ]
    end

    def eol_link(image)
      return unless (eol_url = image.eol_url)

      link_to("EOL", eol_url, target: "_blank", rel: "noopener")
    end

    def edit_and_destroy_links(image)
      return unless check_permission(image)

      [
        link_with_query(:edit_object.t(type: :image),
                        edit_image_path(image.id)),
        destroy_button(name: :destroy_object.t(type: :image),
                       target: image)
      ]
    end

    def email_commercial_inquiry_link(image)
      return unless image.user.email_general_commercial && !image.user.no_emails

      link_with_query(:image_show_inquiry.t,
                      emails_commercial_inquiry_path(image.id))
    end
  end
end
