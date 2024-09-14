# frozen_string_literal: true

require "test_helper"

class InatImportJobTrackersControllerTest < FunctionalTestCase
  def test_show
    tracker = inat_import_job_trackers(:import_tracker_rolf_importing)

    login
    get(:show, params: { id: tracker.id })

    assert_response(:success)
  end
end
