# frozen_string_literal: true

module Views::Controllers::InatImports
  # Shows the progress / completion state of one iNat import.
  # Subscribes to [user, :inat_import] Turbo Stream so the status
  # panel updates automatically whenever InatImport changes.
  class Show < Views::FullPageBase
    prop :inat_import, ::InatImport
    prop :user, ::User

    def view_template
      container_class(:wide)
      add_page_title(:inat_import_tracker.t)
      turbo_stream_from([@inat_import.user, :inat_import])
      render(Status.new(inat_import: @inat_import))
      render_actions
    end

    private

    def render_actions
      div(class: "mt-3") do
        render(Components::Button.new(
                 type: :get,
                 name: :inat_import_tracker_results.l,
                 target: results_observations_path
               ))
        whitespace
        render(::Components::Button.new(
                 type: :put,
                 name: :CANCEL.l,
                 target: inat_import_cancel_path(id: @inat_import)
               ))
      end
    end

    def results_observations_path
      observations_path(
        pattern: "user:#{@user.id} created:" \
                 "#{Time.zone.today}-#{Time.zone.tomorrow}"
      )
    end
  end
end
