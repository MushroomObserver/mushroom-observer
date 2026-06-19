# frozen_string_literal: true

require("test_helper")

module Names::Descriptions
  class VersionsControllerTest < FunctionalTestCase
    def test_show_past_name_description
      login("dick")
      desc = name_descriptions(:peltigera_desc)
      old_versions = desc.versions.length
      desc.update(gen_desc: "something new which refers to _P. aphthosa_")
      desc.reload
      new_versions = desc.versions.length
      assert(new_versions > old_versions)

      get(:show, params: { id: desc.id })

      # `Views::Controllers::Descriptions::Versions::Show` extends
      # `Views::FullPageBase`, so the full Application layout fires:
      # doctype + layout chrome + the page-title slot populated by
      # `add_page_title` from `view_template`.
      assert_response(:success)
      assert_select("html > head > title", count: 1)
      assert_select("body.versions__show")
      assert_select("#description_details_and_alts")
    end
  end
end
