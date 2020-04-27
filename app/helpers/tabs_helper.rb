# html used in tabsets
module TabsHelper
  # Short-hand to render shared tab_set partial for a given set of links.
  def draw_tab_set(links)
    render(partial: "/shared/tab_set", locals: { links: links })
  end

  # assemble HTML for "tabset" for show_observation
  # actually a list of links and the interest icons
  def show_observation_tabset(obs, user)
    tabs = [
      show_obs_google_links_for(obs.name),
      general_questions_link(obs, user),
      notifications_link(obs, user),
      manage_lists_link(obs, user),
      map_link,
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
                    controller: :names,
                    action: :map,
                    id: obs_name.id)
  end

  def general_questions_link(obs, user)
    return unless obs.user.email_general_question && obs.user != user

    link_with_query(:show_observation_send_question.t,
                    controller: :email,
                    action: :ask_observation_question,
                    id: obs.id)
  end

  def notifications_link(obs, user)
    return unless user&.has_unshown_naming_notifications?(obs)

    link_with_query(:show_observation_view_notifications.t,
                    controller: :observations,
                    action: :show_notifications,
                    id: obs.id)
  end

  def manage_lists_link(obs, user)
    return unless user&.species_lists&.any?

    link_with_query(:show_observation_manage_species_lists.t,
                    controller: :species_lists,
                    action: :manage_species_lists,
                    id: obs.id)
  end

  def map_link
    return unless @mappable

    link_with_query(:MAP.t,
                    controller: :locations,
                    action: :map_locations)
  end

  def obs_change_links(obs)
    return unless check_permission(obs)

    [
      link_with_query(:show_observation_edit_observation.t,
                      controller: :observations,
                      action: :edit_observation,
                      id: obs.id),
      link_with_query(:DESTROY.t,
                      { controller: :observations,
                        action: :destroy_observation,
                        id: obs.id },
                      class: "text-danger",
                      data: { confirm: :are_you_sure.l })
    ]
  end

  def prefs_tabset
    tabs = [
      link_to(:bulk_license_link.t,
              controller: :images,
              action: :license_updater),
      link_to(:prefs_change_image_vote_anonymity.t,
              controller: :images,
              action: :bulk_vote_anonymity_updater),
      link_to(:profile_link.t,
              action: :profile),
      link_to(:show_user_your_notifications.t,
              controller: :interests,
              action: :list_interests),
      link_to(:account_api_keys_link.t,
              action: :api_keys)
    ]
    { right: draw_tab_set(tabs) }
  end
end
