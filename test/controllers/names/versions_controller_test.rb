# frozen_string_literal: true

require("test_helper")

module Names
  class VersionsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_show_past_name
      login
      get(:show, params: { id: names(:coprinus_comatus).id })
      assert_template("names/versions/show")
    end

    def test_show_past_name_with_misspelling
      login
      get(:show, params: { id: names(:petigera).id })
      assert_template("names/versions/show")
    end

    def test_show_past_name_version_table_panel
      name = names(:coprinus_comatus)
      login
      get(:show, params: { id: name.id })
      assert_response(:success)

      # Check that the version table panel heading renders
      assert_select("#name_versions .panel-heading") do |elements|
        assert_equal(1, elements.size, "Should find version table panel heading")
        assert_match(/Versions/, elements.first.text)
      end

      # Check that the version table panel body renders with table content
      assert_select("#name_versions .panel-body") do |elements|
        assert_equal(1, elements.size, "Should find version table panel body")
        # Should contain a table
        assert_select(elements.first, "table.table-hover") do |table|
          assert_equal(1, table.size, "Should find versions table")
        end
      end
    end
  end
end
