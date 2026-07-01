# frozen_string_literal: true

require("test_helper")

module Views::Controllers::InatImports::JobTrackers
  class CurrentTest < ComponentTestCase
    def setup
      super
      @import = inat_imports(:lone_wolf_import)
      @tracker = inat_import_job_trackers(:lone_wolf_tracker)
    end

    # Lines 96-102, 108-112: render_ignored_section and render_ignored_row
    def test_ignored_section_shown_when_done_with_ignored_counts
      @import.update!(ignored_not_importable_count: 3,
                      ignored_already_imported_count: 2)

      html = render(Current.new(tracker: @tracker))

      assert_html(html, "h5",
                  text: :inat_import_tracker_ignored_heading.l.as_displayed)
      assert_html(html, "b",
                  text: :inat_import_tracker_ignored_not_importable.l)
      assert_html(html, "b",
                  text: :inat_import_tracker_ignored_already_imported.l)
      assert_no_html(html, "b",
                     "Zero-count date_missing row should not render",
                     text: :inat_import_tracker_ignored_date_missing.l)
    end

    def test_ignored_section_absent_when_no_ignored_obs
      html = render(Current.new(tracker: @tracker))

      assert_no_html(html, "h5",
                     "Ignored heading absent when all counts are zero")
    end
  end
end
