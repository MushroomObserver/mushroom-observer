# frozen_string_literal: true

# html used in buttons
module Buttons
  module ObservationsHelper
    def obs_icon_size
      "fa-lg"
    end

    def obs_icon_style
      "btn-link"
    end

    def obs_change_buttons(obs:)
      return [] unless check_permission(obs)

      # icon_size = "fa-lg" # "fa-sm"
      btn_style = "btn-sm btn-link"
      links = []
      links << edit_button(
        target: obs, name: :show_observation_edit_observation.t,
        class: "btn #{btn_style}"
      )
      links << destroy_button(
        target: obs, name: :show_observation_destroy_observation.t,
        class: "btn #{btn_style}"
      )
    end

    # Using link_to in order to enable icons in these links
    def observation_image_edit_links(obs:)
      links = []
      links << obs_add_images_link(obs)
      links << obs_reuse_images_link(obs)
      links << obs_remove_images_link(obs) if obs.images.length.positive?
      links
    end

    # used by observation_image_edit_links
    def obs_add_images_link(obs)
      link_to(
        add_query_param(new_image_for_observation_path(obs.id)),
        class: "btn #{obs_icon_style} observation_add_images_link_#{obs.id}",
        aria: { label: :show_observation_add_images.t },
        data: { toggle: "tooltip", placement: "top",
                title: :show_observation_add_images.t }
      ) do
        # concat(tag.span(:ADD.t, class: "mr-1"))
        concat(icon("fa-regular", "plus", class: obs_icon_size))
      end
    end

    def obs_reuse_images_link(obs)
      link_to(
        add_query_param(reuse_images_for_observation_path(obs.id)),
        class: "btn #{obs_icon_style} observation_reuse_images_link_#{obs.id}",
        aria: { label: :show_observation_reuse_image.t },
        data: { toggle: "tooltip", placement: "top",
                title: :show_observation_reuse_image.t }
      ) do
        # concat(tag.span(:image_reuse_reuse.t, class: "mr-1"))
        concat(icon("fa-regular", "clone", class: obs_icon_size))
      end
    end

    def obs_remove_images_link(obs)
      link_to(
        add_query_param(remove_images_from_observation_path(obs.id)),
        class: "btn #{obs_icon_style} observation_remove_images_link_#{obs.id}",
        aria: { label: :show_observation_remove_images.t },
        data: { toggle: "tooltip", placement: "top",
                title: :show_observation_remove_images.t }
      ) do
        # concat(tag.span(:image_remove_remove.t, class: "mr-1"))
        concat(icon("fa-regular", "trash", class: obs_icon_size))
      end
    end
  end
end
