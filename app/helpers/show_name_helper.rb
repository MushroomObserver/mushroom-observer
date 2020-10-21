# frozen_string_literal: true

# helpers for ShowName view and ShowNameInfo section of ShowObservation
module ShowNameHelper
  ######## links to searches

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
end
