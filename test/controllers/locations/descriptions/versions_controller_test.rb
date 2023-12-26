# frozen_string_literal: true

require("test_helper")

module Locations::Descriptions
  class VersionsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_show_past_location_description
      login("dick")
      desc = location_descriptions(:albion_desc)
      old_versions = desc.versions.length
      desc.update(gen_desc: "something new")
      desc.reload
      new_versions = desc.versions.length
      assert(new_versions > old_versions)
      get(:show, params: { id: desc.id })
      assert_template(
        "locations/descriptions/versions/show",
        partial: "locations/descriptions/show/_location_description"
      )
    end
  end
end
