# frozen_string_literal: true

# html used in tabsets
module Tabs
  module ImagesHelper
    # link attribute arrays
    def images_index_links(query:)
      # Add "show observations" link if this query can be coerced into an
      # observation query. (coerced_query_link returns array)
      [
        [*coerced_query_link(query, Observation),
         { class: "images_with_observations_link" }]
      ]
    end

    # assemble HTML for "tabset" for show_image
    # actually a list of links and the interest icons
    def show_image_tabset(image:)
      [
        show_image_obs_links(image),
        eol_link(image),
        edit_and_destroy_links(image),
        email_commercial_inquiry_link(image)
      ].flatten.reject(&:empty?)
    end

    def images_exif_show_links(image:)
      [
        [:cancel_and_show.t(type: :image),
         add_query_param(image.show_link_args),
         { class: "image_return_link" }]
      ]
    end

    private

    def show_image_obs_links(image)
      return unless image.observations.length == 1

      obs = image.observations.first
      [
        link_to(:show_object.t(type: :observation),
                add_query_param(permanent_observation_path(obs.id)),
                class: "image_observation_link"),
        link_to(:show_object.t(type: :name),
                add_query_param(name_path(obs.name.id)),
                class: "image_name_link"),
        link_to(:google_images.t,
                "http://images.google.com/images?q=#{obs.name.search_name}",
                target: "_blank", rel: "noopener", class: "image_google_link")
      ]
    end

    def eol_link(image)
      return unless (eol_url = image.eol_url)

      link_to("EOL", eol_url, target: "_blank", rel: "noopener",
                              class: "image_eol_link")
    end

    def edit_and_destroy_links(image)
      return unless check_permission(image)

      [
        link_to(:edit_object.t(type: :image),
                add_query_param(edit_image_path(image.id)),
                class: "image_edit_link"),
        destroy_button(name: :destroy_object.t(type: :image),
                       target: image)
      ]
    end

    def email_commercial_inquiry_link(image)
      return unless image.user.email_general_commercial && !image.user.no_emails

      link_to(:image_show_inquiry.t,
              add_query_param(emails_commercial_inquiry_path(image.id)),
              class: "image_commercial_inquiry_link")
    end
  end
end
