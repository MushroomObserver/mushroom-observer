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
         { class: "images_observations_query_link" }]
      ]
    end

    # assemble links for show_image
    def show_image_links(image:)
      [
        *show_image_obs_links(image),
        image_eol_link(image),
        *image_mod_links(image),
        image_commercial_inquiry_link(image)
      ].reject(&:empty?)
    end

    def images_exif_show_links(image:)
      [object_return_link(image)]
    end

    private

    def show_image_obs_links(image)
      return unless image.observations.length == 1

      obs = image.observations.first
      [
        [:show_object.t(type: :observation),
         add_query_param(permanent_observation_path(obs.id)),
         { class: "image_observation_link" }],
        [:show_object.t(type: :name),
         add_query_param(name_path(obs.name.id)),
         { class: "image_observation_name_link" }],
        [:google_images.t,
         "http://images.google.com/images?q=#{obs.name.search_name}",
         { target: "_blank", rel: "noopener", class: "image_google_link" }]
      ]
    end

    def image_eol_link(image)
      return unless (eol_url = image.eol_url)

      ["EOL", eol_url, { target: "_blank", rel: "noopener",
                         class: __method__.to_s }]
    end

    def image_mod_links(image)
      return unless check_permission(image)

      [
        edit_image_link(image),
        destroy_image_link(image)
      ]
    end

    def edit_image_link(image)
      [:edit_object.t(type: :image),
       add_query_param(edit_image_path(image.id)),
       { class: __method__.to_s }]
    end

    def destroy_image_link(image)
      [:destroy_object.t(type: :image), image, { button: :destroy }]
    end

    def image_commercial_inquiry_link(image)
      return unless image.user.email_general_commercial && !image.user.no_emails

      [:image_show_inquiry.t,
       add_query_param(emails_commercial_inquiry_path(image.id)),
       { class: __method__.to_s }]
    end

    def test_add_image_report_links
      [["Test Again", { action: :test_add_image },
        { class: "test_add_image_report_link" }]]
    end
  end
end
