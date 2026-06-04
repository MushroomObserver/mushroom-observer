# frozen_string_literal: true

# Species Fungorum SF synonymy page external-site link for a
# Name. The "official" synonyms in alpha order page; works for
# species, genus, family.
class Tab::Name::FungorumSfSynonymy < Tab::Name::ExternalBase
  def title
    :sf_species_synonymy.l
  end

  def path
    "http://www.speciesfungorum.org/Names/SynSpecies.asp" \
      "?RecordID=#{@name.icn_id}"
  end
end
