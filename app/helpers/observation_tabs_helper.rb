# frozen_string_literal: true

# html used in tabsets
module ObservationTabsHelper
  # assemble HTML for "tabset" for show_observation
  # actually a list of links and the interest icons
  def show_observation_tabset(obs:, user:, mappable:)
    tabs = [
      show_obs_google_links_for(obs.name),
      general_questions_link(obs, user),
      manage_lists_link(obs, user),
      map_link(mappable),
      obs_change_links(obs),
      draw_interest_icons(obs)
    ].flatten.reject(&:empty?)
    { pager_for: obs, right: draw_tab_set(tabs) }
  end

  def show_obs_google_links_for(obs_name)
    return unless obs_name.known?

    [google_images_for(obs_name), google_distribution_map_for(obs_name)]
  end

  def google_images_for(obs_name)
    link_to(:google_images.t, google_images_link(obs_name))
  end

  def google_images_link(obs_name)
    format("https://images.google.com/images?q=%s", obs_name.real_text_name)
  end

  def google_distribution_map_for(obs_name)
    link_with_query(:show_name_distribution_map.t,
                    map_name_path(id: obs_name.id))
  end

  def general_questions_link(obs, user)
    return if obs.user.no_emails
    return unless obs.user.email_general_question && obs.user != user

    link_with_query(:show_observation_send_question.t,
                    new_question_for_observation_path(obs.id),
                    remote: true, onclick: "MOEvents.whirly();")
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

  def obs_change_links(obs)
    return unless check_permission(obs)

    [
      link_with_query(:show_observation_edit_observation.t,
                      edit_observation_path(obs.id),
                      class: "edit_observation_link_#{obs.id}"),
      destroy_button(target: obs)
    ]
  end

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
