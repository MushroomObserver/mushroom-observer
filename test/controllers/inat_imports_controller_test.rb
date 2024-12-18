# frozen_string_literal: true

require "test_helper"

class InatImportsControllerTest < FunctionalTestCase
  def test_show
    import = inat_imports(:rolf_inat_import)
    tracker = InatImportJobTracker.create(inat_import: import.id)

    login
    get(:show, params: { id: tracker.id })

    assert_response(:success)
    assert_select("span#importables_count", /^\d+$/,
                  "Importables count should be an integer")
    assert_select("span#imported_count", /^\d+$/,
                  "Imported count should be an integer")
  end
end
