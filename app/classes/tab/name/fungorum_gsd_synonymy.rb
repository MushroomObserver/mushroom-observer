# frozen_string_literal: true

# Species Fungorum GSD synonymy page external-site link for a
# Name. The "official" synonyms-by-category page; works for species
# and infra-specific ranks.
class Tab::Name::FungorumGsdSynonymy < Tab::Name::ExternalBase
  def title
    :gsd_species_synonymy.l
  end

  def path
    "http://www.speciesfungorum.org/Names/GSDspecies.asp" \
      "?RecordID=#{@name.icn_id}"
  end
end
