# frozen_string_literal: true

require "test_helper"

class InatImportJobTrackersControllerTest < FunctionalTestCase
  def test_show
    import = inat_imports(:rolf_inat_import)
    tracker = InatImportJobTracker.create(inat_import: import.id)

    login
    get(:show, params: { id: tracker.id })

    assert_response(:success)
  end
end
