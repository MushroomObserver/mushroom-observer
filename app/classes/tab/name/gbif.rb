# frozen_string_literal: true

# GBIF (Global Biodiversity Information Facility) external-site
# link for a Name. Omits the group/sensu_lato suffix because
# including it returns zero hits, and skips quoting so the search
# returns synonyms and cf's.
class Tab::Name::Gbif < Tab::Name::ExternalBase
  def title
    "GBIF"
  end

  def path
    "https://www.gbif.org/species/search?q=#{@name.sensu_stricto}"
  end
end
