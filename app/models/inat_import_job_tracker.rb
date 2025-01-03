# frozen_string_literal: true

# For display of status of an InatImportJob
#
# == Attributes
#
#  inat_import::  the iNatImport for the job
#  status::       the state of the iNat import of this tracker
#
class InatImportJobTracker < ApplicationRecord
  def status
    InatImport.find(inat_import).state
  end
end
