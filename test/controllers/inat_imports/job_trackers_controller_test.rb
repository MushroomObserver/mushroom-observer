# frozen_string_literal: true

require("test_helper")

module InatImports
  class JobTrackersControllerTest < FunctionalTestCase
    include ActionView::Helpers::SanitizeHelper

    def test_show_unstarted
      import = inat_imports(:rolf_inat_import)
      tracker = InatImportJobTracker.create(inat_import: import.id)

      login
      get(:show, params: { inat_import_id: import.id, id: tracker.id },
                 format: :turbo_stream)

      assert_response(:success)
      assert(@response.body.include?("status_#{tracker.id}"))

      # remove HTML tags for easier testing of displayed text
      body = strip_tags(@response.body)

      assert(body.include?("#{:inat_import_tracker_status.l}: Unstarted"))
      importables_line =
        "#{:inat_import_imported.l}: 0 of#{tracker.importables}"
      assert(body.include?(importables_line))
      assert(body.include?("#{:inat_import_tracker_elapsed_time.l}: 00:00:00"))
      assert(body.include?(:inat_import_tracker_estimated_remaining_time.l))
      assert(body.include?(:inat_import_tracker_ended.l))
    end

    def test_show_done
      import = inat_imports(:lone_wolf_import)
      tracker = InatImportJobTracker.create(inat_import: import.id)
      assert(tracker.response_errors.present?,
             "Test needs tracker fixture with response_errors")

      login
      get(:show, params: { inat_import_id: import.id, id: tracker.id },
                 format: :turbo_stream)

      assert_response(:success)
      body = strip_tags(@response.body)

      assert(body.include?("#{:inat_import_tracker_status.l}: Done"))
      assert(body.include?(
               "#{:inat_import_tracker_estimated_remaining_time.l}: 00:00:00"
             ))
      assert(body.include?(tracker.response_errors))
    end
  end
end
