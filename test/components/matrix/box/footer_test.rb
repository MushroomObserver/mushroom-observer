# frozen_string_literal: true

require("test_helper")

# Tests for Components::Matrix::Box::Footer, the mixin included by
# Components::Matrix::Box that owns all footer slot rendering.
#
# Content methods (render_footer_detail, render_footer_time,
# render_user_detail) are tested by creating a minimal anonymous
# Phlex component that includes the module and calls the method
# directly in view_template — same technique as collapsible_test.rb.
#
# Slot-level methods (render_log_footer, render_identify_footer,
# render_project_admin_footer) are tested through a full Box render
# so the Panel slot machinery is exercised.
class MatrixBoxFooterTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  # ---------------------------------------------------------------
  # render_footer_detail
  # ---------------------------------------------------------------

  def test_footer_detail_nil_renders_nothing
    assert_equal("", render_detail(nil))
  end

  def test_footer_detail_empty_string_renders_nothing
    assert_equal("", render_detail(""))
  end

  def test_footer_detail_string_renders_detail_div
    html = render_detail("Some log detail text")

    assert_html(html, "div.rss-detail.small", text: "Some log detail text")
  end

  def test_footer_detail_user_renders_user_info
    user = users(:rolf)
    html = render_detail(user)

    assert_html(html, "div.rss-detail.small")
    assert_html(html,
                "a[href='#{routes.observations_path(by_user: user.id)}']",
                text: :observations.ti.as_displayed)
  end

  # ---------------------------------------------------------------
  # render_footer_time
  # ---------------------------------------------------------------

  def test_footer_time_nil_renders_nothing
    assert_equal("", render_time(nil))
  end

  def test_footer_time_renders_local_time_div
    time = Time.zone.parse("2024-06-01 12:00:00 UTC")
    html = render_time(time)

    assert_html(html,
                "div[data-controller='local-time']" \
                "[data-local-time-utc-value='#{time.utc.iso8601}']")
  end

  # ---------------------------------------------------------------
  # render_project_admin_footer (via full Box render)
  # ---------------------------------------------------------------

  def test_project_admin_footer_shown_for_admin
    project = projects(:bolete_project)
    obs = observations(:coprinus_comatus_obs)
    dick = users(:dick) # member of bolete_admins
    html = render(
      Components::Matrix::Box.new(user: dick, object: obs, project: project)
    )

    expected_path = routes.exclude_observation_project_update_path(
      project_id: project.id, id: obs.id
    )
    assert_html(html, "form[action='#{expected_path}']")
  end

  def test_project_admin_footer_hidden_for_non_admin
    project = projects(:bolete_project)
    obs = observations(:coprinus_comatus_obs)
    html = render(
      Components::Matrix::Box.new(user: @user, object: obs, project: project)
    )

    expected_path = routes.exclude_observation_project_update_path(
      project_id: project.id, id: obs.id
    )
    assert_no_html(html, "form[action='#{expected_path}']")
  end

  def test_project_admin_footer_hidden_without_project
    obs = observations(:coprinus_comatus_obs)
    html = render(
      Components::Matrix::Box.new(user: @user, object: obs)
    )

    assert_no_html(html, "div.panel-footer.text-center")
  end

  private

  # Renders render_footer_detail(detail) in a Phlex context.
  def render_detail(detail)
    render(Class.new(Components::Base) do
      include Components::Matrix::Box::Footer

      define_method(:view_template) { render_footer_detail(detail) }
    end.new)
  end

  # Renders render_footer_time(time) in a Phlex context.
  def render_time(time)
    render(Class.new(Components::Base) do
      include Components::Matrix::Box::Footer

      define_method(:view_template) { render_footer_time(time) }
    end.new)
  end
end
