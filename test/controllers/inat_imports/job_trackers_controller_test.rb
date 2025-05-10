# frozen_string_literal: true

require("test_helper")

module InatImports
  class JobTrackersControllerTest < FunctionalTestCase
    # test that it shows the tracker status.
    # Would need an HTML response, though. (Can you test a turbo response?)
    # def test_show
    #   import = inat_imports(:rolf_inat_import)
    #   tracker = InatImportJobTracker.create(inat_import: import.id)

    #   login
    #   get(:show, params: { inat_import_id: import.id, id: tracker.id })
    #   assert_response(:success)
    #   # maybe check the text
    # end
  end
end
