# frozen_string_literal: true

# Action-nav for the add/remove-observations-from-list form: a
# cancel link back to the observations index (preserving the
# current Query so the filter survives the round trip).
class Tab::SpeciesList::FormObservations < Tab::Collection
  def initialize(index_filter: nil)
    super()
    @index_filter = index_filter
  end

  private

  def tabs
    [Tab::SpeciesList::ObservationsIndexReturn.new(
      index_filter: @index_filter
    )]
  end
end
