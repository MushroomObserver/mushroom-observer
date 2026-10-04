# frozen_string_literal: true

require("test_helper")

module Views::Controllers::InatImports
  class StatusTest < ComponentTestCase
    def setup
      super
      @import = inat_imports(:katrina_inat_import)
    end

    def test_turbo_replace_target_id
      html = render_status

      assert_html(html, "#inat_import_#{@import.id}")
    end

    def test_stimulus_controller_wired
      html = render_status

      assert_html(
        html,
        "#inat_import_#{@import.id}[data-controller='inat-import']"
      )
    end

    def test_stimulus_values_seeded_from_model
      @import.update_columns(
        state: InatImport.states[:Importing],
        importables: 10,
        imported_count: 3
      )
      html = render_status

      assert_html(
        html,
        "[data-inat-import-status-value='Importing']"
      )
    end

    def test_elapsed_and_remaining_targets_present
      html = render_status

      assert_html(html, "[data-inat-import-target='elapsed']")
      assert_html(html, "[data-inat-import-target='remaining']")
    end

    def test_done_state_renders_done_alert
      @import.update_columns(
        state: InatImport.states[:Done],
        ended_at: Time.zone.now
      )
      html = render_status

      assert_html(
        html,
        "[data-inat-import-status-value='Done']"
      )
      assert_html(html, ".alert")
    end

    def test_error_caption_shown_when_errors_present
      @import.update_columns(
        response_errors: "Something went wrong\n"
      )
      html = render_status

      assert_includes(html, :errors.ti)
    end

    def test_results_button_absent_when_not_done
      # katrina_inat_import is in Importing state
      html = render_status

      path = routes.results_inat_import_path(@import)
      assert_no_html(html, "a[href='#{path}']")
    end

    def test_results_button_present_when_done
      @import.update_columns(
        state: InatImport.states[:Done],
        imported_count: 5,
        ended_at: Time.zone.now
      )
      html = render_status

      path = routes.results_inat_import_path(@import)
      assert_html(html, "a[href='#{path}']")
    end

    def test_cancel_button_present_when_importing
      # katrina_inat_import is in Importing state
      html = render_status

      cancel_path = routes.inat_import_cancel_path(id: @import.id)
      assert_html(html, "form[action='#{cancel_path}']")
      assert_html(html, "input[name='_method'][value='put']")
    end

    def test_cancel_button_absent_when_done
      @import.update_columns(
        state: InatImport.states[:Done],
        ended_at: Time.zone.now
      )
      html = render_status

      cancel_path = routes.inat_import_cancel_path(id: @import.id)
      assert_no_html(html, "form[action='#{cancel_path}']")
    end

    def test_date_missing_row_absent_when_no_date_missing_skips
      @import.update_columns(
        state: InatImport.states[:Done],
        ended_at: Time.zone.now,
        ignored_not_importable_count: 1
      )
      html = render_status

      assert_no_html(
        html,
        "*",
        text: :inat_import_tracker_ignored_date_missing.l.as_displayed
      )
    end

    def test_date_missing_row_shown_with_count_and_reimport_link
      @import.update_columns(
        state: InatImport.states[:Done],
        ended_at: Time.zone.now,
        ignored_date_missing_count: 2
      )
      @import.update!(date_missing_inat_ids: [101, 202])
      html = render_status

      reimport_path = routes.new_inat_import_path(inat_ids: "101,202")
      assert_html(html, "a[href='#{reimport_path}']")
    end

    def test_license_added_section_absent_when_no_license_added_obs
      @import.update_columns(
        state: InatImport.states[:Done],
        ended_at: Time.zone.now,
        imported_count: 3
      )
      html = render_status

      assert_no_html(
        html,
        "*",
        text: :inat_import_tracker_license_added_heading.l.as_displayed
      )
    end

    def test_license_added_section_shown_with_reimport_link
      @import.update_columns(
        state: InatImport.states[:Done],
        ended_at: Time.zone.now,
        imported_count: 2,
        ignored_not_importable_count: 1
      )
      @import.update!(license_added_inat_ids: [55, 66])
      html = render_status

      reimport_path = routes.new_inat_import_path(inat_ids: "55,66")
      assert_html(html, "a[href='#{reimport_path}']")
    end

    def test_skeleton_section_absent_when_no_skeletons
      @import.update_columns(state: InatImport.states[:Done],
                             ended_at: Time.zone.now,
                             imported_count: 3, skeleton_imported_count: 0)
      html = render_status

      assert_no_html(html, "#skeleton_imported")
    end

    def test_ignored_unlicensed_row_links_each_obs
      ids = [395_299_285, 395_299_286]
      @import.update_columns(state: InatImport.states[:Done],
                             ended_at: Time.zone.now, imported_count: 0,
                             ignored_unlicensed_count: ids.size)
      @import.update!(unlicensed_inat_ids: ids)
      html = render_status

      assert_html(html, "#ignored_unlicensed b",
                  text: :inat_import_tracker_ignored_unlicensed.l)
      ids.each do |inat_id|
        url = "#{Inat::Constants::SITE}/observations/#{inat_id}"
        assert_html(
          html, "#ignored_unlicensed a[href='#{url}'][target='_blank']",
          text: :inat_import_tracker_unlicensed_images_link.l(inat_id:)
        )
      end
    end

    def test_unlicensed_images_summary_and_linked_list
      events = [
        { "inat_id" => 30, "login" => "Zed", "license_code" => nil,
          "count" => 2 },
        { "inat_id" => 10, "login" => "amy", "license_code" => "cc-by",
          "count" => 1 },
        { "inat_id" => 20, "login" => "Zed", "license_code" => nil,
          "count" => 3 }
      ]
      @import.update_columns(state: InatImport.states[:Done],
                             ended_at: Time.zone.now, imported_count: 3,
                             response_errors: "")
      @import.update!(unlicensed_image_events: events)
      html = render_status

      assert_equal(expected_unlicensed_summary(events, %w[amy Zed]),
                   Nokogiri::HTML5.fragment(html).
                     css("#unlicensed_images_summary > div").map(&:text),
                   "Summary should have one line per iNat user, by login")
      %w[amy Zed].each do |login|
        url = "#{Inat::Constants::SITE}/people/#{login}"
        assert_html(html, "#unlicensed_images_summary " \
                          "a[href='#{url}'][target='_blank']",
                    text: login)
      end
      events.each do |event|
        url = "#{Inat::Constants::SITE}/observations/#{event["inat_id"]}"
        assert_html(
          html, "#unlicensed_images_list a[href='#{url}'][target='_blank']",
          text: :inat_import_tracker_unlicensed_images_link.l(
            inat_id: event["inat_id"]
          )
        )
        user_url = "#{Inat::Constants::SITE}/people/#{event["login"]}"
        assert_html(html, "#unlicensed_images_list a[href='#{user_url}']",
                    text: event["login"])
      end
      assert_no_html(html, ".alert-warning")
    end

    def test_skeleton_section_shown_with_count
      count = 2
      @import.update_columns(state: InatImport.states[:Done],
                             ended_at: Time.zone.now,
                             imported_count: 3,
                             skeleton_imported_count: count)
      html = render_status

      assert_html(html, "#skeleton_imported.alert-success h5",
                  text: :inat_import_tracker_skeleton_imported_heading.l)
      assert_html(
        html, "#skeleton_imported div",
        text: :inat_import_tracker_skeleton_imported_note.t(count:).
              as_displayed
      )
    end

    def test_over_cap_line_absent_when_under_cap
      @import.update_columns(total_importables: InatImport::MAX_IMPORTABLE)
      html = render_status

      assert_no_html(html, "#over_cap_count")
    end

    def test_over_cap_line_shown_with_count
      excess = 50
      @import.update_columns(
        total_importables: InatImport::MAX_IMPORTABLE + excess
      )
      html = render_status

      assert_html(html, "#over_cap_count", text: excess.to_s)
    end

    def test_over_cap_reimport_link_absent_when_not_done
      # katrina_inat_import is in Importing state
      @import.update_columns(
        total_importables: InatImport::MAX_IMPORTABLE + 50
      )
      html = render_status

      reimport_path = routes.new_inat_import_path(
        inat_username: @import.inat_username
      )
      assert_no_html(html, "a[href='#{reimport_path}']")
    end

    def test_over_cap_reimport_link_shown_when_done
      @import.update_columns(
        state: InatImport.states[:Done],
        ended_at: Time.zone.now,
        imported_count: InatImport::MAX_IMPORTABLE,
        total_importables: InatImport::MAX_IMPORTABLE + 50
      )
      html = render_status

      reimport_path = routes.new_inat_import_path(
        inat_username: @import.inat_username
      )
      assert_html(html, "a[href='#{reimport_path}']")
    end

    def test_over_cap_reimport_link_uses_stored_original_ui_url
      original_url = "https://www.inaturalist.org/observations?taxon_id=48701"
      @import.update_columns(
        state: InatImport.states[:Done],
        ended_at: Time.zone.now,
        imported_count: InatImport::MAX_IMPORTABLE,
        total_importables: InatImport::MAX_IMPORTABLE + 50,
        original_inat_url: original_url
      )
      html = render_status

      reimport_path = routes.new_inat_import_path(
        inat_username: @import.inat_username,
        inat_url: original_url
      )
      assert_html(html, "a[href='#{reimport_path}']")
    end

    def test_over_cap_reimport_link_uses_stored_original_api_url
      original_url =
        "https://api.inaturalist.org/v1/observations?taxon_id=48701"
      @import.update_columns(
        state: InatImport.states[:Done],
        ended_at: Time.zone.now,
        imported_count: InatImport::MAX_IMPORTABLE,
        total_importables: InatImport::MAX_IMPORTABLE + 50,
        original_inat_url: original_url
      )
      html = render_status

      reimport_path = routes.new_inat_import_path(
        inat_username: @import.inat_username,
        inat_url: original_url
      )
      assert_html(html, "a[href='#{reimport_path}']")
    end

    def test_over_cap_reimport_link_falls_back_when_no_original_url
      stored_query = "taxon_id=48701&user_login=katrina"
      @import.update_columns(
        state: InatImport.states[:Done],
        ended_at: Time.zone.now,
        imported_count: InatImport::MAX_IMPORTABLE,
        total_importables: InatImport::MAX_IMPORTABLE + 50,
        original_inat_url: nil,
        inat_url: stored_query
      )
      html = render_status

      reimport_path = routes.new_inat_import_path(
        inat_username: @import.inat_username,
        inat_url: "#{Inat::Constants::SITE}/observations?#{stored_query}"
      )
      assert_html(html, "a[href='#{reimport_path}']")
    end

    def test_importables_count_uncapped_when_under_cap
      @import.update_columns(
        importables: 4, total_importables: 4, imported_count: 3
      )
      html = render_status

      assert_html(html, "#total_importables_count", text: "4")
    end

    def test_importables_count_capped_when_over_cap
      @import.update_columns(
        total_importables: InatImport::MAX_IMPORTABLE + 50,
        imported_count: InatImport::MAX_IMPORTABLE
      )
      html = render_status

      assert_html(html, "#total_importables_count",
                  text: InatImport::MAX_IMPORTABLE.to_s)
    end

    private

    def render_status
      render(Status.new(inat_import: @import))
    end

    def expected_unlicensed_summary(events, logins)
      logins.map do |login|
        user_events = events.select { |event| event["login"] == login }
        counts = :inat_import_tracker_unlicensed_images_summary.l(
          obs_count: user_events.size,
          photo_count: user_events.sum { |e| e["count"] }
        )
        "#{login}: #{counts}"
      end
    end
  end
end
