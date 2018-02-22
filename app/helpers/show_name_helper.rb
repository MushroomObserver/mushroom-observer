# frozen_string_literal: true
#
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

  # array of lines for other accepted synonyms, each line comprising
  # link to observations of synonym and a count of those observations
  #   Chlorophyllum rachodes (Vittadini) Vellinga (96)
  #   Chlorophyllum rhacodes (Vittadini) Vellinga (63)
  def obss_by_syn_links(name)
    name.other_approved_synonyms.each_with_object([]) do |synonym, lines|
      query = synonym.obss_of_name
      next if query.select_count.zero?

      lines << link_to_obss_of(query, synonym.display_name.t)
    end
  end

  # link to an Observation query, followed by count of results
  # returns nil if no results
  # Use:
  #   link_to_obss_of(name.obss_of_taxon, :obss_of_taxon.t)
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
