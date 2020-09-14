# frozen_string_literal: true

# helpers for ShowName view and ShowNameInfo section of ShowObservation
module ShowNameHelper
  ######## links to searches
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
    query = Query.lookup(:Observation, :all, names: name.id, by: :confidence)
    link_to_obss_of(query, :obss_of_this_name.t)
  end

  # link to a search for Observations of this taxon (under any name) + count
  def taxon_observations(name)
    link_to_obss_of(obss_of_taxon(name), :obss_of_taxon.t)
  end

  # link to a search for observations of this taxon, under other names + count
  def taxon_obss_other_names(name)
    link_to_obss_of(obss_of_taxon_other_names(name), :taxon_obss_other_names.t)
  end

  # link to a search for observations where this taxon was proposed + count
  # (but is not the consensus)
  def taxon_proposed(name)
    link_to_obss_of(obss_other_taxa_this_taxon_proposed(name),
                    :obss_taxon_proposed.t)
  end

  # link to a search for observations where this name was proposed
  def name_proposed(name)
    link_to_obss_of(obss_this_name_proposed(name),
                    :obss_name_proposed.t)
  end

  # array of lines for other accepted synonyms, each line comprising
  # link to observations of synonym and a count of those observations
  #   Chlorophyllum rachodes (Vittadini) Vellinga (96)
  #   Chlorophyllum rhacodes (Vittadini) Vellinga (63)
  def obss_by_syn_links(name)
    name.other_approved_synonyms.each_with_object([]) do |name2, lines|
      query = Query.lookup(:Observation, :all, names: name2.id, by: :confidence)
      next if query.select_count.zero?

      lines << link_to_obss_of(query, name2.display_name_brief_authors.t)
    end
  end

  # return link to a query for observations + count of results
  # returns nil if no results
  # Use:
  #   query = Query.lookup(:Observation, :all, names: name.id, by: :confidence,
  #                        include_synonyms: true)
  #   link_to_obss_of(query, :obss_of_taxon.t)
  #   => <a href="/observer/index_observation?q=Q">This Taxon, any name</a> (19)
  def link_to_obss_of(query, title)
    count = query.select_count
    return nil if count.zero?

    query.save
    link_to(
      title,
      add_query_param(
        { controller: :observer, action: :index_observation }, query
      )
    ) + " (#{count})"
  end

  # link to a search for species of name's genus. Sample text:
  #   List of species in Amanita Pers. (1433)
  def show_obs_genera(name)
    return unless (genus = name.genus)

    query = species_in_genus(genus)
    count = query.select_count
    query.save unless browser.bot?
    return unless count > 1

    link_to(
      :show_consensus_species.t(name: genus.display_name_brief_authors.t),
      add_query_param({ controller: :name, action: :index_name }, query)
    ) + " (#{count})"
  end

  ######## searches

  # These are extracted for isolation and to facilitate testing

  def obss_of_taxon(name)
    Query.lookup(:Observation, :all,
                 names: name.id,
                 include_synonyms: true,
                 by: :confidence)
  end

  def obss_of_taxon_other_names(name)
    Query.lookup(:Observation, :all,
                 names: name.id,
                 include_synonyms: true,
                 exclude_original_names: true,
                 by: :confidence)
  end

  def obss_other_taxa_this_taxon_proposed(name)
    Query.lookup(:Observation, :all,
                 names: name.id,
                 include_synonyms: true,
                 include_all_name_proposals: true,
                 exclude_consensus: true,
                 by: :confidence)
  end

  def obss_this_name_proposed(name)
    Query.lookup(:Observation, :all,
                 names: name.id,
                 include_all_name_proposals: true,
                 by: :confidence)
  end

  def species_in_genus(genus)
    Query.lookup(:Name, :all,
                 names: genus.id,
                 include_subtaxa: true,
                 exclude_original_names: true)
  end
end
