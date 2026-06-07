# frozen_string_literal: true

# "Observations of this Name (N)" link in the Name-show
# observations-menu panel. Query restricts to observations whose
# consensus is exactly this Name (no synonyms).
class Tab::Name::ObsLink::ThisName < Tab::Name::ObsLink
  private

  def label_key
    :obss_of_this_name
  end

  def build_query
    q = Query.create_query(:Observation,
                           names: { lookup: @name.id },
                           order_by: :confidence)
    q.save
    q
  end
end
