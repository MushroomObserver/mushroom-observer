# frozen_string_literal: true

# For display of status of an InatImportJob
#
# == Attributes
#
#  created_at::   when the tracker was created
#  inat_import::  the iNatImport for the job
#  updated_at::   when the tracker was updated
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
end
