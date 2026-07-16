# frozen_string_literal: true

# Runs CheckRssLogsJob's orphan/bogus-type checks for just :observation
# -- see CheckRssLogsJob's own comment for why this one type gets split
# out on its own (it dominated the combined job's runtime, measured
# locally: ~46% of the total, driven by `observations` being by far the
# largest of the seven reference tables).
class CheckObservationRssLogsJob < CheckRssLogsJob
  private

  def check_types
    [:observation]
  end
end
