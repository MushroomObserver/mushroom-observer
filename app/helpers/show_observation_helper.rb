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

  # string of links to Names of any other non-deprecated synonyms
  def show_obs_approved_syn_links(obs)
    name = obs.name
    return unless name && !name.unknown? && !browser.bot?
    return if (approved_synonyms = name.other_approved_synonyms).blank?

    links = approved_synonyms.map {|n| name_link(n)}
    label = if name.deprecated
              :show_observation_preferred_names.t
            else
              :show_observation_alternative_names.t
            end

    label + ": " + content_tag(:span, links.safe_join(", "), class: :Data)
  end

  # array of lines with links to Observations of all synonyms of name + count
  #  Macrolepiota rachodes (Vittadini) Singer (1)
  #  Chlorophyllum rachodes (Vittadini) Vellinga (96)
  #  Chlorophyllum rhacodes (Vittadini) Vellinga (63)
  def obss_by_syn_links(name)
    data = []
    for name2 in ([name] + name.other_approved_synonyms)
      query = Query.lookup(:Observation, :of_name, name: name2, by: :confidence)
      count = query.select_count
      if count > 0
        query.save
        data << {count: count, name: name2, query: query}
      end
    end
    lines = []
    if data.length > 1
      for datum in data
        name2 = datum[:name]
        query = datum[:query]
        count = datum[:count]
        lines << link_to(:show_name_observations_of.t(name: name2.display_name),
                          add_query_param({ controller: :observer,
                                            action: :index_observation },
                                            query)
        ) + " (#{count})"
      end
    end
    lines
  end

  # link to a search for species of name's genus. Sample text:
  #   List of species in Amanita Pers. (1433)
  def show_obs_genera(name)
    return  unless (genus = name.genus)
    query = Query.lookup(:Name, :of_children, name: genus, all: true)
    count = query.select_count
    query.save if !browser.bot?
    return unless count > 1

    link_to(:show_consensus_list_of_species.t(name: genus.display_name.t),
            add_query_param({ controller: :name, action: :index_name },
                            query)
           ) + " (#{count})"
  end
end
