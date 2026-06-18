# frozen_string_literal: true

require("test_helper")

module Locations::Descriptions
  class VersionsControllerTest < FunctionalTestCase
    def test_show_past_location_description
      login("dick")
      desc = location_descriptions(:albion_desc)
      old_versions = desc.versions.length
      desc.update(gen_desc: "something new")
      desc.reload
      new_versions = desc.versions.length
      assert(new_versions > old_versions)

      get(:show, params: { id: desc.id })

      # `Views::Controllers::Descriptions::Versions::Show` extends
      # `Views::FullPageBase`, so the Application layout fires —
      # doctype + chrome + page-title slot populated.
      assert_response(:success)
      assert_select("html > head > title", count: 1)
      assert_select("body.versions__show")
      assert_select("#description_details_and_alts")
    end
  end
end
