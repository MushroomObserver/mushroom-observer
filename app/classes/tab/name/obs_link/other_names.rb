# frozen_string_literal: true

# "Observations of this taxon under other names (N)" link. Query
# expands to the synonym set then excludes the original name —
# leaves only observations whose consensus is a synonym of this
# Name.
class Tab::Name::ObsLink::OtherNames < Tab::Name::ObsLink
  private

  def label_key
    :taxon_obss_other_names
  end

  def build_query
    q = Query.create_query(
      :Observation,
      names: { lookup: @name.id, include_synonyms: true,
               exclude_original_names: true },
      order_by: :confidence
    )
    q.save
    q
  end
end
