# frozen_string_literal: true

# Mix into any model with a `where` string column and a
# `belongs_to :location`, to get a viewer-aware `place_name`/
# `place_name=` pair. Used by Observation, Project, and SpeciesList.
#
# `place_name(user)` is viewer-aware (nil => postal default), matching
# `Location#display_name`/`Location.normalize_place_name`. `place_name=`
# can't take that same explicit second argument through plain `=`
# syntax, so it reads `current_user` (an explicit per-instance
# accessor the caller sets before assignment) instead.
#
# A host whose `location` association needs eager-load-safe lookup
# (Observation, which may be reached after a bare `location_id =`
# invalidated the cached association target) overrides
# +location_for_place_name+ instead of +place_name+ itself.
module HasPlaceName
  extend ActiveSupport::Concern

  included do
    attr_accessor :current_user
  end

  def place_name(user = nil)
    if (loc = location_for_place_name)
      loc.display_name(user)
    elsif user&.location_format == "scientific"
      Location.reverse_name(where)
    else
      where
    end
  end

  def place_name=(place_name)
    where = Location.normalize_place_name(place_name, current_user)
    loc = Location.find_by_name(where)
    if loc
      self.where = loc.name
      self.location = loc
    else
      self.where = where
      self.location = nil
    end
  end

  private

  def location_for_place_name
    location
  end
end
