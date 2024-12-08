# frozen_string_literal: true

# html used in tabsets
module Tabs
  module ImagesHelper
    # link attribute arrays
    def images_index_tabs(query:)
      [coerced_observation_query_tab(query)]
    end

    # assemble links for show_image
    def show_image_tabs(image:)
      [
        *show_image_obs_tabs(image),
        image_eol_tab(image),
        *image_mod_tabs(image),
        image_commercial_inquiry_tab(image)
      ].reject(&:empty?)
    end

    def images_exif_show_tabs(image:)
      [object_return_tab(image)]
    end

    def images_index_sorts
      [
        ["name",          :sort_by_name.t],
        ["original_name", :sort_by_filename.t],
        ["date",          :sort_by_date.t],
        ["user",          :sort_by_user.t],
        # ["copyright_holder", :sort_by_copyright_holder.t],
        ["created_at",    :sort_by_posted.t],
        ["updated_at",    :sort_by_updated_at.t],
        ["confidence",    :sort_by_confidence.t],
        ["image_quality", :sort_by_image_quality.t],
        ["num_views",     :sort_by_num_views.t]
      ].freeze
    end

    private

    def show_image_obs_tabs(image)
      return unless image.observations.length == 1

      obs = image.observations.first
      [
        show_object_tab(obs),
        show_object_tab(obs.name),
        name_google_images_tab(obs.name)
      ]
    end

    def name_google_images_tab(name)
      [:google_images.t,
       "http://images.google.com/images?q=#{name.search_name}",
       { target: "_blank", rel: "noopener", class: tab_id(__method__.to_s) }]
    end

    def image_eol_tab(image)
      return unless (eol_url = image.eol_url)

      ["EOL", eol_url, { target: "_blank", rel: "noopener",
                         class: tab_id(__method__.to_s) }]
    end

    def image_mod_tabs(image)
      return unless check_permission(image)

      [
        edit_image_tab(image),
        destroy_image_tab(image)
      ]
    end

    def edit_image_tab(image)
      [:edit_object.t(type: :image),
       add_query_param(edit_image_path(image.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def destroy_image_tab(image)
      [:destroy_object.t(type: :image), image, { button: :destroy }]
    end

    def image_commercial_inquiry_tab(image)
      return unless image.user.email_general_commercial && !image.user.no_emails

      [:image_show_inquiry.t,
       add_query_param(new_commercial_inquiry_for_image_path(image.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def test_add_image_report_tabs
      [["Test Again", { action: :test_add_image },
        { class: "test_add_image_report_link" }]]
    end
  end
end
