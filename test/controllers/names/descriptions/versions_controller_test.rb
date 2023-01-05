# frozen_string_literal: true

require("test_helper")
require("set")

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
      get(:show_past_name_description, params: { id: desc.id })
      assert_template(:show_past_name_description)
      assert_template("name/_name_description")
    end

  end
end
