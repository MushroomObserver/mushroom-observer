# frozen_string_literal: true

module InatImportJobTrackersHelper
  def import_done?(inat_import)
    inat_import.state == "Done"
  end

  def import_incomplete?(inat_import)
    inat_import.state != "Done"
  end

  def time_in_hours_minutes_seconds(seconds)
    return :inat_import_tracker_calculating_time.l if seconds.nil?

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    seconds %= 60
    format("%02d:%02d:%02d", hours, minutes, seconds)
  end
end
