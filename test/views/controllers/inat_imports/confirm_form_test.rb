# frozen_string_literal: true

require("test_helper")

module Views::Controllers::InatImports
  class ConfirmFormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      @import = inat_imports(:rolf_inat_import)
      @form_model = FormObject::InatImportConfirm.new(
        inat_username: "rolf_inat_username"
      )
    end

    def test_basic_form_structure
      html = render_form

      assert_html(html, "form[action='#{routes.inat_imports_path}']")
      assert_html(html, "button[name='confirmed'][value='1']")
      assert_html(html, "button[name='go_back'][value='1']")
      assert_html(html, "#expected_count")
      assert_html(html, "#unlicensed_obs_count")
      assert_html(html, "#estimated_time")
      assert_html(html, "#as_of")
    end

    def test_carries_inat_username_through_hidden_field
      html = render_form

      assert_html(html,
                  "input[type='hidden']" \
                  "[name='inat_import_confirm[inat_username]']")
    end

    def test_carries_recheck_all_through_hidden_field
      html = render_form

      assert_html(html,
                  "input[type='hidden']" \
                  "[name='inat_import_confirm[recheck_all]']")
    end

    def test_staleness_note_absent_when_result_set_is_stable
      stable_model = FormObject::InatImportConfirm.new(
        inat_username: "rolf_inat_username", inat_ids: "123,456"
      )
      html = render_form(form_model: stable_model)

      assert_no_html(html, ".staleness-note")
    end

    def test_staleness_note_present_when_result_set_unstable
      html = render_form

      assert_html(html, ".staleness-note")
    end

    def test_staleness_note_present_for_date_filtered_url
      model = FormObject::InatImportConfirm.new(
        inat_url: "https://www.inaturalist.org/observations" \
                  "?user_id=jdcohenesq&d1=2026-05-01&d2=2026-05-31"
      )
      html = render_form(form_model: model)

      assert_html(html, ".staleness-note")
    end

    def test_requested_count_absent_when_not_provided
      html = render_form

      assert_no_html(html, "#requested_count")
    end

    def test_requested_count_present_when_provided
      html = render_form(breakdown: { requested: 12, after_taxon: 10 })

      assert_html(html, "#requested_count")
    end

    def test_no_ignored_section_when_no_breakdown_counts
      html = render_form

      assert_no_html(html, "#total_ignored_count")
    end

    def test_ignored_total_shown_with_requested_and_expected
      html = render_form(
        breakdown: { requested: 12, after_taxon: 10, estimate_with_date: 9 }
      )

      assert_html(html, "#total_ignored_count")
    end

    def test_overlap_note_absent_with_single_ignored_row
      # Only not_importable row: requested(12) - after_taxon(10) = 2 > 0
      # already_imported: after_taxon(10) - expected(10) = 0, not positive
      # no_date: nil (no estimate_with_date provided)
      html = render_form(breakdown: { requested: 12, after_taxon: 10 })

      assert_no_html(html, ".overlap-note")
    end

    def test_overlap_note_present_with_multiple_ignored_rows
      # not_importable (requested - after_taxon = 2) +
      # already_imported (after_taxon - expected = 3) +
      # no_date (expected - estimate_with_date = 1)
      html = render_form(
        breakdown: {
          requested: 20, after_taxon: 18, estimate_with_date: 14
        }
      )

      assert_html(html, ".overlap-note")
    end

    def test_nothing_to_import_notice_absent_when_expected_positive
      html = render_form(expected: 5)

      assert_no_html(html, "#inat_import_confirm_nothing_to_import")
    end

    def test_nothing_to_import_notice_shown_when_expected_zero
      html = render_form(expected: 0)

      assert_html(html, "p",
                  text: :inat_import_confirm_nothing_to_import.l)
    end

    def test_proceed_button_disabled_when_expected_zero
      html = render_form(expected: 0)

      assert_html(html, "button[name='confirmed'][disabled]")
    end

    def test_proceed_button_enabled_when_expected_positive
      html = render_form(expected: 5)

      assert_no_html(html, "button[name='confirmed'][disabled]")
    end

    def test_unlicensed_obs_count_rendered_as_link_when_url_available
      html = render_form(unlicensed_obs: 3)

      assert_html(html, "#unlicensed_obs_count a[href]")
    end

    def test_unlicensed_obs_count_rendered_as_plain_text_without_url
      model = FormObject::InatImportConfirm.new(inat_username: "")
      html = render_form(form_model: model, unlicensed_obs: 3)

      assert_html(html, "#unlicensed_obs_count")
    end

    def test_unlicensed_others_note_when_import_others
      model = FormObject::InatImportConfirm.new(
        inat_username: "rolf_inat_username", import_others: "1"
      )
      html = render_form(form_model: model, unlicensed_obs: 2)

      assert_html(html, "#unlicensed_obs_count")
    end

    def test_time_estimate_from_base_constant_when_no_import
      html = render_form(inat_import: nil)

      assert_html(html, "#estimated_time")
    end

    private

    def render_form(form_model: @form_model, inat_import: @import,
                    expected: 10, unlicensed_obs: 0, breakdown: {})
      inat_import_val = inat_import
      render(ConfirmForm.new(
               form_model,
               expected: expected,
               unlicensed_obs: unlicensed_obs,
               breakdown: {
                 inat_import: inat_import_val,
                 requested: breakdown[:requested],
                 after_taxon: breakdown[:after_taxon],
                 estimate_with_date: breakdown[:estimate_with_date]
               }
             ))
    end
  end
end
