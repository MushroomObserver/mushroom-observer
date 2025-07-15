# frozen_string_literal: true

# For display of status of an InatImportJob
#
# == Attributes
#  inat_import::   id of the iNatImport for the job
#
# == Methods
#  status::        state of the iNat import of this tracker
#  elapsed_time::  time since the tracker was created
#  help::          help message displayed at the bottom of the page
#
class InatImportJobTracker < ApplicationRecord
  delegate :ended_at, to: :import
  delegate :importables, to: :import
  delegate :imported_count, to: :import
  delegate :avg_import_time, to: :import
  delegate :response_errors, to: :import
  delegate :total_expected_time, to: :import

  def status
    import.state
  end

  def elapsed_time
    end_time = if status == "Done"
                 ended_at
               else
                 Time.zone.now
               end
    (end_time - created_at).to_i
  end

  def estimated_remaining_time
    # Can't calculate remaining time unless we know # of Obss to be imported
    return nil unless importables.to_i&.positive?
    return 0 if status == "Done"

    [total_expected_time - elapsed_time, 0].max
  end

  def error_caption
    if response_errors.blank?
      ""
    else
      "#{:ERRORS.t}: "
    end
  end

  def help
    if status == "Done"
      :inat_import_tracker_done.l
    else
      :inat_import_tracker_leave_page.l
    end
  end

  private

  def import
    InatImport.find(inat_import)
  end
end
