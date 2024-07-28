# frozen_string_literal: true

class API2
  # Must supply both latitude and longitude, can't leave one out.
  class LatLongMustBothBeSet < FatalError
  end
end
