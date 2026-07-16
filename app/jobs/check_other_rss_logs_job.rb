# frozen_string_literal: true

# Runs CheckRssLogsJob's orphan/bogus-type checks for every
# RssLog::ALL_TYPE_TAGS type except :observation (see
# CheckObservationRssLogsJob), plus the ghost-row check -- ghosts aren't
# specific to any one type, so there's no reason to run that check
# twice across the two jobs.
class CheckOtherRssLogsJob < CheckRssLogsJob
  private

  def check_types
    RssLog::ALL_TYPE_TAGS - [:observation]
  end

  def check_ghosts?
    true
  end
end
