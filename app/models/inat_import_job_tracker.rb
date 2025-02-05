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

  def status
    import.state
  end

  def elapsed
    end_time = if status == "Done"
                 ended_at
               else
                 Time.zone.now
               end
    total_seconds = (end_time - created_at).to_i
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    seconds = total_seconds % 60
    format("%d:%02d:%02d", hours, minutes, seconds)
  end

  private

  def import
    InatImport.find(inat_import)
  end
end
