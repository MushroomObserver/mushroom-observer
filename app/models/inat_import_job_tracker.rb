# frozen_string_literal: true

# For display of status of an InatImportJob
#
# == Attributes
#
#  created_at::   when the tracker was created
#  updated_at::   when the tracker was updated
#  inat_import::  the iNatImport for the job
#  ended_at::     when the job was Done
#
# == Methods
#  status::       the state of the iNat import of this tracker
#
class InatImportJobTracker < ApplicationRecord
  def importables
    InatImport.find(inat_import).importables
  end

  def imported_count
    InatImport.find(inat_import).imported_count
  end

  def status
    InatImport.find(inat_import).state
  end

  def elapsed
    to_time = if status == "Done"
                ended_at
              else
                Time.zone.now
              end
    total_seconds = (to_time - created_at).to_i
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    seconds = total_seconds % 60
    format("%d:%02d:%02d", hours, minutes, seconds)
  end
end
