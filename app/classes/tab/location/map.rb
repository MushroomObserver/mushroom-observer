# frozen_string_literal: true

# "Map of place names" link rendered on the locations index. Threads
# the current query through so the map filters to the same locations.
class Tab::Location::Map < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :list_place_names_map.t
  end

  def path
    with_q_param(map_locations_path, @q_param)
  end
end
