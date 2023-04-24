# frozen_string_literal: true

# html used in tabsets
module ObservationTabsHelper
  # assemble HTML for "tabset" for show_observation
  # actually a list of links and the interest icons
  def show_observation_tabset(obs:, user:)
    tabs = [
      general_questions_link(obs, user),
      manage_lists_link(obs, user),
      # obs_change_links(obs: obs),
      draw_interest_icons(obs)
    ].flatten.reject(&:empty?)
    { pager_for: obs, right: draw_tab_set(tabs) }
  end

  def name_links_on_mo(name:, mappable:)
    [
      tag.p(link_to(:show_name.t(name: name.display_name_brief_authors),
                    name_path(name.id))),
      tag.p(link_to(:show_observation_more_like_this.t,
                    observations_path(name: name.id))),
      tag.p(link_to(:show_observation_look_alikes.t,
                    observations_path(name: name.id,
                                      look_alikes: "1"))),
      tag.p(link_to(:show_observation_related_taxa.t,
                    observations_path(name: name.id,
                                      related_taxa: "1"))),
      list_descriptions(object: name)&.map do |link|
        tag.div(link)
      end,
      map_link(mappable)
    ].flatten.reject(&:empty?)
  end

  def name_links_web(name:)
    [
      tag.p(link_to("MyCoPortal", mycoportal_url(name),
                    target: :_blank, rel: :noopener)),
      tag.p(link_to("Mycobank", mycobank_name_search_url(name),
                    target: :_blank, rel: :noopener)),
      tag.p(google_images_for(name)),
      tag.p(google_distribution_map_for(name))
    ].flatten.reject(&:empty?)
  end

  def show_obs_google_links_for(name)
    return unless name.known?

    [google_images_for(name), google_distribution_map_for(name)]
  end

  def google_images_for(name)
    link_to(:google_images.t, google_images_link(name))
  end

  def google_images_link(name)
    format("https://images.google.com/images?q=%s", name.real_text_name)
  end

  def google_distribution_map_for(name)
    link_with_query(:show_name_distribution_map.t,
                    map_name_path(id: name.id))
  end

  def general_questions_link(obs, user)
    return if obs.user.no_emails
    return unless obs.user.email_general_question && obs.user != user

    link_with_query(:show_observation_send_question.t,
                    emails_ask_observation_question_path(obs.id))
  end

  def manage_lists_link(obs, user)
    return unless user

    link_with_query(:show_observation_manage_species_lists.t,
                    edit_observation_species_lists_path(obs.id))
  end

  def map_link(mappable)
    return unless mappable

    link_with_query(:MAP.t, map_locations_path)
  end

  def obs_icon_size
    "fa-lg"
  end

  def obs_icon_style
    "btn-link"
  end

  def obs_change_links(obs:)
    return [] unless check_permission(obs)

    # icon_size = "fa-lg" # "fa-sm"
    btn_style = "btn-sm btn-link"
    links = []
    links << edit_button(
      target: obs, name: :show_observation_edit_observation.t,
      class: "btn #{btn_style}"
    )
    links << destroy_button(
      target: obs, name: "#{:DESTROY.t} #{:OBSERVATION.t}",
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

  # INDEX

  def index_observation_tabset(query:)
    tabs = [
      tabs_at_where(query),
      index_map_tab(query),
      coerced_query_tabs(query),
      add_to_list_tab(query),
      download_as_csv_tab(query)
    ].flatten.reject(&:empty?)
    { right: draw_tab_set(tabs) }
  end

  def tabs_at_where(query)
    # Add some extra links to the index user is sent to if they click on an
    # undefined location.
    return unless query.flavor == :at_where

    [
      link_with_query(:list_observations_location_define.l,
                      new_location_path(
                        where: query.params[:user_where]
                      )),
      link_with_query(:list_observations_location_merge.l,
                      location_merges_form_path(
                        where: query.params[:user_where]
                      )),
      link_with_query(:list_observations_location_all.l,
                      locations_path)
    ]
  end

  def index_map_tab(query)
    link_to(:show_object.t(type: :map),
            map_observations_path(q: get_query_param(query)))
  end

  # NOTE: coerced_query_link returns an array
  def coerced_query_tabs(query)
    [
      link_to(*coerced_query_link(query, Location)),
      link_to(*coerced_query_link(query, Name)),
      link_to(*coerced_query_link(query, Image))
    ]
  end

  def add_to_list_tab(query)
    link_to(:list_observations_add_to_list.t,
            add_query_param(edit_species_list_observations_path, query))
  end

  def download_as_csv_tab(query)
    link_to(:list_observations_download_as_csv.t,
            add_query_param(new_observations_download_path, query))
  end
end
