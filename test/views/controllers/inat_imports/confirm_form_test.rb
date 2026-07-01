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
      # requested(10) - estimate_with_date(6) = 4 total ignored; 2 rows → note
      html = render_form(expected: 8,
                         breakdown: { requested: 10, after_taxon: 8,
                                      estimate_with_date: 6 })

      assert_html(html, "#total_ignored_count", text: "4")
      assert_html(html, "small.overlap-note",
                  text: :inat_import_confirm_ignored_overlap_note.l.
                        as_displayed)
      assert_html(html, "b",
                  text: :inat_import_confirm_not_importable_caption.l)
      assert_html(html, "b",
                  text: :inat_import_confirm_no_date_caption.l)
    end

    def test_expected_count_links_to_inat_when_url_constructable
      html = render_form(expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_html(html, "#expected_count a[href*='iconic_taxa']" \
                        "[target='_blank']")
    end

    def test_expected_obs_url_adds_date_filter_when_none_present
      html = render_form(expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_html(html, "#expected_count " \
                        "a[href*='d1=#{Inat::Constants::EARLIEST_DATE_FILTER}']")
    end

    def test_expected_obs_url_preserves_user_supplied_date
      url = "#{Inat::Constants::SITE}/observations?user_id=joe&d1=2020-01-01"
      html = render_form(model_attrs: { inat_ids: nil, inat_url: url },
                         expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_html(html, "#expected_count a[href*='d1=2020-01-01']")
      assert_no_html(
        html,
        "#expected_count " \
        "a[href*='d1=#{Inat::Constants::EARLIEST_DATE_FILTER}']",
        "User-supplied d1 should not be replaced with the default"
      )
    end

    def test_expected_count_shows_timestamp_note
      html = render_form(expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_html(html, "#as_of")
      assert_html(html, ".staleness-note",
                  text: :inat_import_confirm_expected_staleness.l.
                        as_displayed)
    end

    def test_expected_count_omits_note_when_no_expected
      html = render_form(expected: nil,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_no_html(html, "#as_of",
                     "Timestamp note absent when expected count is nil")
    end

    def test_staleness_note_suppressed_when_importing_inat_ids
      html = render_form(model_attrs: { inat_ids: "1,2,3" },
                         expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_html(html, "#as_of")
      assert_no_html(html, ".staleness-note",
                     "Staleness note absent when importing specific iNat IDs")
    end

    def test_staleness_note_suppressed_when_url_has_id_param
      url = "#{Inat::Constants::SITE}/observations?id=12345"
      html = render_form(model_attrs: { inat_ids: nil, inat_url: url },
                         expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_no_html(html, ".staleness-note",
                     "Staleness note absent when URL has id param")
    end

    def test_staleness_note_suppressed_when_url_has_past_d2
      url = "#{Inat::Constants::SITE}/observations?user_id=joe&d2=2020-01-01"
      html = render_form(model_attrs: { inat_ids: nil, inat_url: url },
                         expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_no_html(html, ".staleness-note",
                     "Staleness note absent when URL has past d2")
    end

    def test_staleness_note_suppressed_when_url_has_past_year
      url = "#{Inat::Constants::SITE}/observations?user_id=joe&year=2020"
      html = render_form(model_attrs: { inat_ids: nil, inat_url: url },
                         expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_no_html(html, ".staleness-note",
                     "Staleness note absent when URL filtered to past year")
    end

    def test_expected_count_plain_when_no_url_constructable
      html = render_form(model_attrs: { inat_ids: nil, inat_username: nil },
                         expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_html(html, "#expected_count", text: "5")
      assert_no_html(html, "#expected_count a",
                     "No link when URL cannot be constructed")
    end

    def test_ignored_section_already_imported_row_with_link
      # after_taxon(10) - expected(8) = 2 already-imported; total = 2, 1 row
      # inat_ids set → already_imported_url returns a URL → link rendered
      html = render_form(model_attrs: { inat_ids: "1,2,3" },
                         expected: 8,
                         breakdown: { requested: 10, after_taxon: 10,
                                      estimate_with_date: 8 })

      assert_html(html, "#total_ignored_count", text: "2")
      assert_no_html(html, "small.overlap-note",
                     "Overlap note absent with only one ignored row")
      assert_html(html, "a[href*='field:Mushroom']")
    end

    def test_requested_count_translates_multi_taxon_id_to_iconic_taxa
      url = "https://www.inaturalist.org/observations?taxon_id=47170,47685"
      html = render_form(model_attrs: { inat_ids: nil, inat_url: url },
                         expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_html(html, "#requested_count a[href*='iconic_taxa']")
      assert_no_html(html, "#requested_count a[href*='taxon_id']",
                     "Multi-value taxon_id replaced with iconic_taxa in link")
    end

    def test_ignored_section_unlicensed_row_links_to_inat
      # import_others: "1" + inat_ids set → unlicensed_obs_url returns a URL
      html = render_form(model_attrs: { inat_ids: "1,2,3",
                                        import_others: "1" },
                         unlicensed_obs: 2,
                         expected: 5,
                         breakdown: { requested: 5, after_taxon: 5,
                                      estimate_with_date: 5 })

      assert_html(html, "a[href*='licensed=false']")
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
