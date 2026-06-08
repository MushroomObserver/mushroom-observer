# frozen_string_literal: true

# "Observations where this Name was proposed (N)" link. Joins
# through Namings (not just the consensus) for this exact Name —
# observations whose consensus may be different, but where this
# Name appears among the proposed Namings.
class Tab::Name::ObsLink::NameProposed < Tab::Name::ObsLink
  private

  def label_key
    :obss_name_proposed
  end

  def build_query
    q = Query.create_query(
      :Observation,
      names: { lookup: @name.id, include_all_name_proposals: true },
      order_by: :confidence
    )
    q.save
    q
  end
end
