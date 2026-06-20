# frozen_string_literal: true

module Views::Controllers::InatImports
  # Shows the progress / completion state of one iNat import. The
  # `status_<tracker_id>` container is what the Stimulus
  # `inat-import-job` controller polls to refresh.
  class Show < Views::FullPageBase
    prop :tracker, ::InatImportJobTracker
    prop :inat_import, ::InatImport
    prop :user, ::User

    def view_template
      container_class(:wide)
      add_page_title(:inat_import_tracker.t)

      render_status_container
      render_actions
    end

    private

    def render_status_container
      div(id: "status_#{@tracker.id}", data: status_container_data) do
        render(JobTrackers::Current.new(tracker: @tracker))
      end
    end

    def status_container_data
      {
        controller: "inat-import-job",
        endpoint: inat_import_job_tracker_path(
          inat_import_id: @tracker.inat_import,
          id: @tracker.id
        )
      }
    end

    def render_actions
      div(class: "mt-3") do
        render(Components::Button::Get.new(
                 name: :inat_import_tracker_results.l,
                 target: results_observations_path
               ))
        render(::Components::Button::Put.new(
                 name: :CANCEL.l,
                 target: inat_import_cancel_path(id: @tracker.inat_import)
               ))
      end
    end

    # NOTE: when available, swap this to a link filtered to the
    # observations created by `@user` between the tracker's
    # started_at and ended_at (and ideally with `source: :InatImport`),
    # ordered by created_at desc. (jdc 2025-02-08)
    def results_observations_path
      # `Date#strftime` with no format string raises `ArgumentError`;
      # use `Date#to_s` (default `:iso8601` → `YYYY-MM-DD`), which
      # is what the observations `pattern:` parser expects.
      observations_path(
        pattern: "user:#{@user.id} created:" \
                 "#{Time.zone.today}-#{Time.zone.tomorrow}"
      )
    end
  end
end
