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

    private

    def render_status
      render(Status.new(inat_import: @import))
    end
  end
end
