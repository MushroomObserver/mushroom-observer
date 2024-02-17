# frozen_string_literal: true

require("test_helper")

module Names::Descriptions
  class VersionsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_show_past_name_description
      login("dick")
      desc = name_descriptions(:peltigera_desc)
      old_versions = desc.versions.length
      desc.update(gen_desc: "something new which refers to _P. aphthosa_")
      desc.reload
      new_versions = desc.versions.length
      assert(new_versions > old_versions)
      get(:show, params: { id: desc.id })
      assert_template("names/descriptions/versions/show")
      assert_template("descriptions/_show_description_details")
    end
  end
end
