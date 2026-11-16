# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects
  class ProjectTableTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
    end

    def test_renders_one_row_per_project
      eol = projects(:eol_project)
      bolete = projects(:bolete_project)
      html = render_table([eol, bolete])

      assert_html(html, "table tr", count: 2)
      assert_html(html, "a[href*='projects/#{eol.id}']")
      assert_html(html, "a[href*='projects/#{bolete.id}']")
      assert_html(html, "small", text: eol.created_at.web_time)
      assert_html(html, ".badge-id", count: 2)
    end

    def test_open_membership_badge
      project = projects(:eol_project)
      project.open_membership = true
      html = render_table([project])

      assert_html(html, "span", text: :open.ti)
    end

    def test_closed_membership_no_badge
      project = projects(:eol_project)
      project.open_membership = false
      html = render_table([project])

      assert_no_html(html, "span", text: :open.ti)
    end

    def test_no_manage_section_without_observation_context
      project = projects(:eol_project)
      html = render_table([project])

      assert_no_html(html, "form")
    end

    # The index page's case: no `remove`/`add`, always a count badge
    # (even "0") keyed off `observation_counts`.
    def test_renders_count_badge_from_observation_counts
      project = projects(:eol_project)
      html = render_table([project], observation_counts: { project.id => 7 })

      assert_html(html, ".count-badge", text: "7")
    end

    def test_renders_zero_count_badge_when_project_missing_from_hash
      project = projects(:eol_project)
      html = render_table([project])

      assert_html(html, ".count-badge", text: "0")
    end

    def test_remove_button
      project = projects(:eol_project)
      obs = observations(:coprinus_comatus_obs)
      html = render_table([project], observation: obs, remove: true)

      assert_html(
        html,
        "form[action='#{routes.observation_project_path(
          id: obs.id, project_id: project.id
        )}'] button"
      )
      assert_html(html, "input[name='_method'][value='delete']")
      assert_no_html(html, ".count-badge")
    end

    def test_add_button
      project = projects(:eol_project)
      obs = observations(:coprinus_comatus_obs)
      html = render_table([project], observation: obs, add: true)

      assert_html(
        html,
        "form[action='#{routes.observation_project_path(
          id: obs.id, project_id: project.id
        )}'] button"
      )
      assert_html(html, "input[name='_method'][value='put']")
      assert_no_html(html, ".count-badge")
    end

    # `violation_kinds_for` is only consulted on the add side -- stub
    # it rather than relying on a fixture combination that triggers it.
    def test_violation_warning_when_adding_with_violations
      project = projects(:eol_project)
      obs = observations(:coprinus_comatus_obs)
      project.define_singleton_method(:violation_kinds_for) do |_obs|
        [:date, :bbox]
      end
      html = render_table([project], observation: obs, add: true)

      assert_html(html, ".badge-warning",
                  text: :form_observations_projects_kind_date.l)
      assert_html(html, ".badge-warning",
                  text: :form_observations_projects_kind_bbox.l)
    end

    def test_no_violation_warning_when_removing
      project = projects(:eol_project)
      obs = observations(:coprinus_comatus_obs)
      project.define_singleton_method(:violation_kinds_for) do |_obs|
        [:date]
      end
      html = render_table([project], observation: obs, remove: true)

      assert_no_html(html, ".badge-warning")
    end

    private

    def routes
      Rails.application.routes.url_helpers
    end

    def render_table(objects, **)
      render(ProjectTable.new(objects, **))
    end
  end
end
