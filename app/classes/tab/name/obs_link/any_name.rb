# frozen_string_literal: true

# "Observations of this taxon under any name (N)" link. Query
# expands to the synonym set without exclusion — covers both this
# Name's observations and observations consensus'd to any synonym.
class Tab::Name::ObsLink::AnyName < Tab::Name::ObsLink
  private

  def label_key
    :obss_of_taxon
  end

  def build_query
    q = Query.create_query(
      :Observation,
      names: { lookup: @name.id, include_synonyms: true },
      order_by: :confidence
    )
    q.save
    q
  end
end
