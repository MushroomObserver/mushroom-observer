# frozen_string_literal: true

# For display of status of an InatImportJob
#
# == Attributes
#
#  created_at::   when the tracker was created
#  updated_at::   when the tracker was updated
#  inat_import::  id of the iNatImport for the job
#
# == Methods
#  status::       the state of the iNat import of this tracker
#  elapsed::      time since the tracker was created
#
class InatImportJobTracker < ApplicationRecord
  delegate :ended_at, to: :import
  delegate :importables, to: :import
  delegate :imported_count, to: :import
  delegate :response_errors, to: :import

  def status
    import.state
  end

  def elapsed_time
    end_time = if status == "Done"
                 ended_at
               else
                 Time.zone.now
               end
    end_time - created_at
  end

  def estimated_remaining_time
    # Can't calculate remaining time until we've imported at least one obs
    return nil unless imported_count&.positive?

    remaining_importables = importables - imported_count
    cumulative_avg_import_time = elapsed_seconds / imported_count
    (remaining_importables * cumulative_avg_import_time).to_i
  end

  def time_in_hours_minutes_seconds(seconds)
    return "Calculating..." if seconds.nil?

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    seconds %= 60
    format("%02d:%02d:%02d", hours, minutes, seconds)
  end

  def error_caption
    if response_errors.blank?
      ""
    else
      "#{:ERRORS.t}: "
    end
  end

  private

  def import
    InatImport.find(inat_import)
  end

  def elapsed_seconds
    end_time = if status == "Done"
                 ended_at
               else
                 Time.zone.now
               end
    (end_time - created_at).to_i
  end
end
