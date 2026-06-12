# frozen_string_literal: true

# Action-nav for the add/remove-observations-from-list form: a
# cancel link back to the observations index (preserving the
# current Query so the filter survives the round trip).
class Tab::SpeciesList::FormObservations < Tab::Collection
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  private

  def tabs
    [Tab::SpeciesList::ObservationsIndexReturn.new(q_param: @q_param)]
  end
end
