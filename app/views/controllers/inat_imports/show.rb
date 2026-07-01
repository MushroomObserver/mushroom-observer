# frozen_string_literal: true

module Views::Controllers::InatImports
  # Shows the progress / completion state of one iNat import.
  # Subscribes to [user, :inat_import] Turbo Stream so the status
  # panel updates automatically whenever InatImport changes.
  class Show < Views::FullPageBase
    prop :inat_import, ::InatImport
    prop :user, ::User

    def view_template
      container_class(:text)
      add_page_title(:inat_import_tracker.t)
      turbo_stream_from([@inat_import.user, :inat_import])
      render(Status.new(inat_import: @inat_import))
    end
  end
end
