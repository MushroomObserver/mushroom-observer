# encoding: utf-8
# helpers for show Observation view
module ShowObservationHelper
  def show_obs_title(obs)
    @owner_id ? show_obs_title_site_id(obs) : show_obs_title_num_after_name(obs)
  end

  # Observation: Agaricus (5)
  def show_obs_title_num_after_name(obs)
    capture do
      concat(:show_observation_header.t)
      concat(" #{obs.id || "?"}: ")
      concat(obs.name.format_name.t)
    end
  end

  # Observation 5: Agaricus (Site ID)
  def show_obs_title_site_id(obs)
    capture do
      concat(:show_observation_header.t)
      concat(" #{obs.id || "?"}: ")
      concat(obs.name.format_name.t)
      concat(" (#{:show_observation_site_id.t})")
    end
  end

  def owner_id_line(obs)
    return unless obs.show_owner_id?
    capture do
      concat(:show_observation_owner_id.t + ": ")
      concat(obs.owner_favorite_or_explanation.t)
    end
  end

  # array of links to pages about Name, e.g.:
  #   About Polyozellus
  #   Polyozellus on MyCoPortal
  #   Polyozellus on MycoBank
  def show_obs_name_links(obs)
    links = []
    if name = obs.name
      links << link_to(:show_name.t(name: name.display_name), controller: :name,
                     action: :show_name, id: name.id)
      links << link_to(name.display_name.t + " " + :show_name_on_mycoportal.t,
                     mycoportal_url(name), target: :_blank)
      links << link_to(name.display_name.t + " " + :show_name_on_mycobank.t,
                     mycobank_url(name), target: :_blank)
    end
    links
  end
end
