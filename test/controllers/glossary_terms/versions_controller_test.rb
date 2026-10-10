# frozen_string_literal: true

require("test_helper")

# tests of Versions controller
module GlossaryTerms
  class VersionsControllerTest < FunctionalTestCase
    ESSENTIAL_ATTRIBUTES = %w[name description].freeze

    def test_show_past
      term = glossary_terms(:square_glossary_term)
      version = term.versions.first # oldest version

      login
      get(:show, params: { id: term.id, version: version.version })

      assert_response(:success)
      assert_head_title(:show_past_glossary_term_title.l(num: version.version,
                                                         name: term.name))

      ESSENTIAL_ATTRIBUTES.each do |attr|
        assert_select("#glossary_term_version_summary",
                      /#{version.send(attr)}/,
                      "Page is missing glossary term #{attr}")
      end
      assert_select("a[href='#{glossary_term_path(term.id)}']", true,
                    "Page should have link to last (current) version")
    end

    def test_show_past_with_thumb_image
      term = glossary_terms(:plane_glossary_term)
      image = images(:plane_image_thumb)
      assert_equal(term.thumb_image_id, image.id,
                   "Test needs a term whose current thumb_image persists " \
                   "across versions")
      version = term.versions.first # oldest version

      login
      get(:show, params: { id: term.id, version: version.version })

      assert_response(:success)
      assert_select("#glossary_term_version_summary img.image_#{image.id}",
                    true, "Page is missing the term's thumbnail image")
    end
  end
end
