# frozen_string_literal: true
#
# Wrappers around, and modifications of, various Query's
class Name < AbstractModel
  def obss_of_name(by: :confidence)
    ::Query.lookup(:Observation, :of_name, name: self, by: by,
                                           synonyms: :no)
  end

  def obss_of_taxon(by: :confidence)
    ::Query.lookup(:Observation, :of_name, name: self, by: by,
                                           synonyms: :all)
  end

  def obss_of_taxon_other_names(by: :confidence)
    ::Query.lookup(:Observation, :of_name, name: self, by: by,
                                           synonyms: :exclusive)
  end

  def obss_of_other_taxa_this_name_proposed(by: :confidence)
    ::Query.lookup(
      :Observation, :of_name,
      name: self, by: by,
      nonconsensus: :all,
      where: [
        "(observations.name_id NOT IN (#{synonyms.map(&:id).join(",")}) OR
          COALESCE(observations.vote_cache,0) < 0)"
      ]
    )
  end

  def obss_of_other_taxa_this_taxon_proposed(by: :confidence)
    ::Query.lookup(:Observation, :of_name, name: self, by: by,
                                           synonyms: :all,
                                           nonconsensus: :exclusive)
  end
end
