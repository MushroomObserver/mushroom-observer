# helpers for ShowName view and ShowNameInfo section of ShowObservation
module ShowNameHelper
  # string of links to Names of any other non-deprecated synonyms
  def approved_syn_links(name)
    return if (approved_synonyms = name.other_approved_synonyms).blank?

    links = approved_synonyms.map { |n| name_link(n) }
    label = if name.deprecated
              :show_observation_preferred_names.t
            else
              :show_observation_alternative_names.t
            end
    label + ": " + content_tag(:span, links.safe_join(", "), class: :Data)
  end

  # link to a search for Observations of name and a count of those observations
  #   This Name (1)
  def obss_of_name(name)
    query = Query.lookup(:Observation, :of_name, name: name, by: :confidence)
    link_to_obss_of(query, :obss_of_this_name.t)
  end

  # link to a search for Observations of this taxon (under any name) + count
  def taxon_observations(name)
    query = Query.lookup(:Observation, :of_name,
                         name: name, by: :confidence, synonyms: :all)
    link_to_obss_of(query, :obss_of_taxon.t)
  end

  # link to a search for observations of this taxon, under other names + count
  def taxon_obss_other_names(name)
    query = Query.lookup(:Observation, :of_name,
                         name: name, by: :confidence, synonyms: :exclusive)
    link_to_obss_of(query, :taxon_obss_other_names.t)
  end

  # link to a search for observations where this taxon was proposed + count
  # (but is not the consensus)
  def taxon_proposed(name)
    query = Query.lookup(:Observation, :of_name,
                         name: name, by: :confidence, synonyms: :all,
                         nonconsensus: :exclusive)
    link_to_obss_of(query, :obss_taxon_proposed.t)
  end

  # link to a search for observations where this name was proposed + count
  # (but this taxon is not the consensus)
  def name_proposed(name)
    query = Query.lookup(:Observation, :of_name,
                         name: name, by: :confidence, synonyms: :no,
                         nonconsensus: :exclusive)
    link_to_obss_of(query, :obss_name_proposed.t)
  end

  # return link to a query for observations + count of results
  # returns nil of no results
  # Use:
  #   query = Query.lookup(:Observation, :of_name, name: name, by: :confidence,
  #                        synonyms: :all)
  #   link_to_obss_of(query, :obss_of_taxon.t)
  #   => <a href="/observer/index_observation?q=Q">This Taxon, any name</a> (19)
  def link_to_obss_of(query, title)
    count = query.select_count
    return nil if count.zero?
    query.save
    link_to(
      title, add_query_param({ controller: :observer,
                               action: :index_observation }, query)
    ) + " (#{count})"
  end

  # array of lines for other accepted synonyms, each line comprising
  # link to observations of synonym and a count of those observations
  #   Chlorophyllum rachodes (Vittadini) Vellinga (96)
  #   Chlorophyllum rhacodes (Vittadini) Vellinga (63)
  def obss_by_syn_links(name)
    name.other_approved_synonyms.each_with_object([]) do |nm, lines|
      query = Query.lookup(:Observation, :of_name, name: nm, by: :confidence)
      next if query.select_count.zero?

      lines << link_to_obss_of(query, nm.display_name.t)
    end
  end

  # link to a search for species of name's genus. Sample text:
  #   List of species in Amanita Pers. (1433)
  def show_obs_genera(name)
    return  unless (genus = name.genus)
    query = Query.lookup(:Name, :of_children, name: genus, all: true)
    count = query.select_count
    query.save unless browser.bot?
    return unless count > 1

    link_to(
      :show_consensus_species.t(name: genus.display_name.t),
      add_query_param({ controller: :name, action: :index_name }, query)
    ) + " (#{count})"
  end
end
