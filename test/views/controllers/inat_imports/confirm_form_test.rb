# frozen_string_literal: true

require("test_helper")

module Views::Controllers::InatImports
  class ConfirmFormTest < ComponentTestCase
    def setup
      super
      @inat_import = inat_imports(:rolf_inat_import)
    end

    # Line 63: plain(@requested.to_s) — when requested_obs_url is nil
    # (no inat_ids, original_inat_url, inat_url, or inat_username set)
    def test_requested_count_plain_when_no_url_constructable
      html = render_form(model_attrs: { inat_ids: nil, inat_username: nil },
                         expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_html(html, "#requested_count", text: "5")
      assert_no_html(html, "#requested_count a",
                     "No link when URL cannot be constructed")
    end

    def test_ignored_section_not_importable_and_no_date_rows
      # requested(10) - after_taxon(8) = 2 not-importable
      # expected(8) - estimate_with_date(6) = 2 no-date; total = 4, 2 rows
      html = render_form(expected: 8,
                         breakdown: { requested: 10, after_taxon: 8,
                                      estimate_with_date: 6 })

      assert_html(html, "#total_ignored_count", text: "4")
      assert_html(html, "small",
                  text: :inat_import_confirm_ignored_overlap_note.l.
                        as_displayed)
      assert_html(html, "b",
                  text: :inat_import_confirm_not_importable_caption.l)
      assert_html(html, "b",
                  text: :inat_import_confirm_no_date_caption.l)
    end

    def test_ignored_section_already_imported_row_with_link
      # after_taxon(10) - expected(8) = 2 already-imported; total = 2, 1 row
      # inat_ids set → already_imported_url returns a URL → link rendered
      html = render_form(model_attrs: { inat_ids: "1,2,3" },
                         expected: 8,
                         breakdown: { requested: 10, after_taxon: 10,
                                      estimate_with_date: 8 })

      assert_html(html, "#total_ignored_count", text: "2")
      assert_no_html(html, "small",
                     "Overlap note absent with only one ignored row")
      assert_html(html, "a[href*='with_field=Mushroom+Observer+URL']")
    end

    # Lines 63, 143-144, 184, 208-209, 173:
    # already_imported row without URL (already_imported_url → nil)
    def test_ignored_section_already_imported_row_no_link_when_no_url
      # No ids/url/username → requested_obs_url nil → already_imported_url nil
      html = render_form(model_attrs: { inat_ids: nil, inat_username: nil },
                         expected: 8,
                         breakdown: { requested: 10, after_taxon: 10,
                                      estimate_with_date: 8 })

      assert_html(html, "#requested_count")
      assert_no_html(html, "a[href*='with_field']",
                     "No already-imported link when URL cannot be constructed")
    end

    private

    def render_form(model_attrs: {}, expected: 5, unlicensed_obs: nil,
                    breakdown: {})
      defaults = { inat_username: "joe" }
      model = FormObject::InatImportConfirm.new(defaults.merge(model_attrs))
      render(ConfirmForm.new(
               model,
               expected: expected,
               unlicensed_obs: unlicensed_obs,
               breakdown: { inat_import: @inat_import }.merge(breakdown)
             ))
    end
  end
end
