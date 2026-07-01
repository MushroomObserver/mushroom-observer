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

      assert_includes(html, :ERRORS.t)
    end

    def test_results_button_disabled_when_not_done
      # katrina_inat_import is in Importing state
      html = render_status

      assert_html(html, "a[aria-disabled='true'][href*='/observations']")
    end

    def test_results_button_enabled_when_done_with_imports
      @import.update_columns(
        state: InatImport.states[:Done],
        imported_count: 5,
        ended_at: Time.zone.now
      )
      html = render_status

      assert_html(html, "a[href*='/observations'][href*='pattern=']")
      assert_no_html(html, "a[aria-disabled='true']")
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

    private

    def render_status
      render(Status.new(inat_import: @import))
    end
  end
end
