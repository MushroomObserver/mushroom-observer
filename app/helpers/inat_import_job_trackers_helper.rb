# frozen_string_literal: true

module InatImportJobTrackersHelper
  def import_successful?(inat_import)
    inat_import.state == "Done" && inat_import.imported_count.positive?
  end

  def import_incomplete?(inat_import)
    inat_import.state != "Done"
  end
end
