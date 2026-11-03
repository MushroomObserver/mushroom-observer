# frozen_string_literal: true

# "Map" link on the species-list show page's action-tab strip -- the
# observations map, filtered by whatever query the page is already
# showing.
class Tab::SpeciesList::Map < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :map.ti
  end

  def path
    map_observations_path(q: @q_param)
  end

  def alt_title
    "map"
  end
end
