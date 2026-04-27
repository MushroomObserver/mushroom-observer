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
        assert_equal(1, elements.size,
                     "Should find version table panel heading")
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

    # When a version row's classification is NULL but the name's
    # accepted_genus has a classified version that brackets this
    # version's edit time, the version page should render the genus's
    # classification with an "Inherited from …" annotation (#4166).
    def test_show_past_name_classification_inherited_from_genus
      genus = names(:agaricus)
      species = names(:agaricus_campestras)
      User.current = rolf
      genus.update!(classification: "Phylum: _Basidiomycota_\r\nFamily: _New_")
      genus.versions.order(:version).last.update_column(
        :updated_at, 3.days.ago
      )
      species_v = species.versions.order(:version).first ||
                  species.versions.create!(classification: nil)
      species_v.update_columns(classification: nil, updated_at: 1.day.ago)

      login
      get(:show, params: { id: species.id, version: species_v.version })
      assert_response(:success)
      assert_select("#name_classification") do
        assert_match(/Basidiomycota/, response.body)
        assert_match(/Inherited from/, response.body)
      end
    end
  end
end
