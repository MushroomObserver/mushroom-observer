# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::FieldSlips
  class NewTest < ComponentTestCase
    def setup
      super
      @project = projects(:eol_project)
      @member = users(:katrina)
      @non_member = users(:dick)
    end

    def test_renders_tracker_table_for_a_member_with_trackers
      trackers = @project.trackers.order(id: :desc).to_a

      html = render_new(user: @member, trackers: trackers)

      assert_html(html, "tbody#field_slip_job_trackers")
      trackers.each do |tracker|
        assert_html(html, "tr#field_slip_job_tracker_#{tracker.id}")
      end
    end

    # The tbody still renders (CSS hides the empty table -- see
    # .table-field-slip-trackers in _tables.scss) so a Turbo Stream
    # prepend has a target even before any tracker exists.
    def test_tracker_table_tbody_present_but_empty_for_a_member_with_none
      html = render_new(user: @member, trackers: [])

      assert_html(html, "tbody#field_slip_job_trackers")
      assert_no_html(html, "tbody#field_slip_job_trackers tr")
    end

    def test_omits_tracker_table_for_non_member_even_with_trackers
      trackers = @project.trackers.order(id: :desc).to_a

      html = render_new(user: @non_member, trackers: trackers)

      assert_no_html(html, "#field_slip_job_trackers")
    end

    private

    def render_new(user:, trackers:)
      render(New.new(
               project: @project, user: user,
               field_slip_max: 60, trackers: trackers
             ))
    end
  end
end
