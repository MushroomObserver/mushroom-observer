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
    format("http://images.google.com/images?q=%s", obs_name.real_text_name)
  end

  def google_distribution_map_for(obs_name)
    link_with_query(:show_name_distribution_map.t,
                    controller: :name, action: :map, id: obs_name.id)
  end

  def general_questions_link(obs, user)
    return if obs.user.no_emails
    return unless obs.user.email_general_question && obs.user != user

    link_with_query(:show_observation_send_question.t,
                    controller: :emails, action: :ask_observation_question,
                    id: obs.id)
  end

  def manage_lists_link(obs, user)
    return unless user

    link_with_query(:show_observation_manage_species_lists.t,
                    controller: :species_list, action: :manage_species_lists,
                    id: obs.id)
  end

  def map_link(mappable)
    return unless mappable

    link_with_query(:MAP.t, controller: :location, action: :map_locations)
  end

  def obs_change_links(obs)
    return unless check_permission(obs)

    [
      link_with_query(:show_observation_edit_observation.t,
                      edit_observation_path(obs.id)),
      destroy_button(target: obs)
    ]
  end
end
