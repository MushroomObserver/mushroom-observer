# frozen_string_literal: true

module InatImportJobTrackersHelper
  def import_done?(inat_import)
    inat_import.state == "Done"
  end

  def import_incomplete?(inat_import)
    inat_import.state != "Done"
  end
end
