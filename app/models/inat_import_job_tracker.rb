# frozen_string_literal: true

# For display of status of an InatImportJob
class InatImportJobTracker < ApplicationRecord
  belongs_to :inat_import
end
