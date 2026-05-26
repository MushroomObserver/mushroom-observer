# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::Violations
  class FormTest < ComponentTestCase
    def setup
      super
      @project = projects(:falmouth_2023_09_project)
      @admin = @project.user
    end

    def test_renders_one_row_per_violation
      violations = @project.violations
      html = render_form(violations: violations)

      violations.each do |v|
        assert_html(html, "a[href*='#{v.obs.id}']")
      end
      assert_html(html, "table.project-violations")
      # tbody has one row per violation (header tr lives in thead)
      body = html.scan(%r{<tbody>(.*?)</tbody>}m).first.first
      assert_equal(violations.size, body.scan("<tr").size)
    end

    def test_renders_kind_labels_per_row
      violations = @project.violations
      html = render_form(violations: violations)

      violations.each do |v|
        v.kinds.each do |kind|
          assert_includes(html, :"form_violations_kind_#{kind}".l)
        end
      end
    end

    def test_violations_sorted_by_sort_name_in_render
      violations = @project.violations
      html = render_form(violations: violations)

      rendered_ids = html.scan(/observation_link_(\d+)/).
                     flatten.map(&:to_i).uniq
      expected_ids = violations.map { |v| v.obs.id }
      assert_equal(expected_ids, rendered_ids,
                   "Rows should render in violations order (sort_name asc)")
    end

    def test_no_violations_message
      proj = projects(:eol_project)
      html = render_form(project: proj, violations: [], user: proj.user)

      assert_includes(html, :form_violations_no_violations.l)
      assert_no_html(html, "table")
    end

    def test_admin_sees_exclude_buttons
      violations = @project.violations
      html = render_form(violations: violations)

      # button_to renders a <form method=post> with a hidden _method=put
      # and a <button type=submit>Label</button>.
      assert_includes(html, :form_violations_action_exclude.l)
      assert_html(html, "form.button_to[action$='/violations']")
      assert_html(html,
                  "input[type='hidden'][name='project[do]'][value='exclude']")
      assert_html(html, "input[type='hidden'][name='_method'][value='put']")
    end

    def test_admin_sees_extend_button_on_date_violation
      proj = setup_date_violation_project
      date_v = proj.violations.find { |v| v.kinds.include?(:date) }
      assert(date_v, "Setup must produce a date violation")

      html = render_form(project: proj, violations: proj.violations,
                         user: proj.user)

      assert_includes(html, :form_violations_action_extend.l)
      assert_html(html,
                  "input[type='hidden'][name='project[do]'][value='extend']")
    end

    def test_admin_sees_add_target_name_button_on_target_name_violation
      proj = setup_target_name_violation_project
      name_v = proj.violations.find { |v| v.kinds.include?(:target_name) }
      assert(name_v, "Setup must produce a target_name violation")

      html = render_form(project: proj, violations: proj.violations,
                         user: proj.user)

      assert_includes(html, :form_violations_action_add_target_name.l)
      assert_html(html,
                  "input[type='hidden'][name='project[do]']" \
                  "[value='add_target_name']")
    end

    # Post-#4304: the modal itself is fetched on demand from
    # `target_location_modal_project_violations_path` and never appears
    # in the eagerly-rendered violations form. What this form *does*
    # emit is the trigger link with the modal-toggle wiring.
    def test_admin_sees_add_target_location_trigger
      proj = setup_target_location_violation_project
      target_loc_v =
        proj.violations.find { |v| v.kinds.include?(:target_location) }
      assert(target_loc_v,
             "Setup must produce a target_location violation; check Burbank " \
             "vs Falmouth fixture pairing")

      html = render_form(project: proj, violations: proj.violations,
                         user: proj.user)
      obs_id = target_loc_v.obs.id
      modal_id = "location_target_modal_#{obs_id}"
      href = "/projects/#{proj.id}/violations/" \
             "target_location_modal?obs_id=#{obs_id}"

      assert_html(html, "a[href='#{href}']",
                  text: :form_violations_action_add_target_location.l)
      assert_html(
        html,
        "a[data-controller='modal-toggle']" \
        "[data-modal='#{modal_id}']" \
        "[data-action='modal-toggle#showModal:prevent']" \
        "[data-modal-toggle-always-fresh-value='true']"
      )
      # And the modal itself is NOT in this view — it's fetched on demand.
      assert_no_html(html, "##{modal_id}")
    end

    def test_non_admin_only_sees_exclude_for_own_obs
      proj = setup_date_violation_project
      own_violation = proj.violations.find do |v|
        v.obs.user_id == users(:roy).id
      end
      others_violation =
        proj.violations.find { |v| v.obs.user_id != users(:roy).id }
      assert(own_violation && others_violation,
             "Setup must yield violations from the test user and someone else")

      html = render_form(project: proj, violations: proj.violations,
                         user: users(:roy))

      # Exclude button is keyed by obs_id; the form contains an
      # `input[name='project[obs_id]'][value='<id>']`. After the
      # namespacing pass, all action params live under `project[...]`
      # so they share a single dispatch shape in the controller.
      assert_html(
        html,
        "input[name='project[obs_id]'][value='#{own_violation.obs.id}']"
      )
      assert_no_html(
        html,
        "input[name='project[obs_id]'][value='#{others_violation.obs.id}']",
        "Other user's obs should not have an Exclude form for non-admin"
      )
      # Admin-only actions are not rendered for non-admin.
      assert_no_html(html, "input[value='extend']")
      assert_no_html(html, "input[value='add_target_name']")
      assert_no_html(html, "input[value='add_target_location']")
    end

    # Tests that previously asserted modal *contents* on this view —
    # Create-link attrs, existing-radio enabled state, help paragraph,
    # country-suffix filtering, no-suffixes message — moved to:
    #   - test/components/target_location_form_test.rb (form internals)
    #   - test/components/target_location_modal_test.rb (modal wrapper +
    #     no-suffixes branch)
    # because the modal is now fetched on demand and isn't part of this
    # view's HTML output (#4304).

    private

    def render_form(violations:, project: @project, user: @admin)
      render(Views::Controllers::Projects::Violations::Form.new(
               project: project, violations: violations, user: user
             ))
    end

    # Project keyed only on date constraints, with a roy-owned obs out of
    # range so test_non_admin_only_sees_exclude_for_own_obs has a target.
    def setup_date_violation_project
      proj = projects(:falmouth_2023_09_project)
      # Falmouth project already has multi-user violations; make sure
      # there's at least one obs owned by `roy`.
      roy_obs = observations(:nybg_2023_09_obs)
      roy_obs.update!(user: users(:roy)) unless roy_obs.user == users(:roy)
      proj
    end

    def setup_target_name_violation_project
      proj = projects(:rare_fungi_project)
      proj.project_target_locations.destroy_all
      proj.project_target_names.destroy_all
      proj.update!(start_date: nil, end_date: nil, location: nil)
      proj.add_target_name(names(:agaricus))
      off_target = observations(:peltigera_obs)
      proj.add_observation(off_target)
      proj
    end

    def setup_target_location_violation_project
      proj = projects(:rare_fungi_project)
      # rare_fungi_project already has burbank as a target_location via
      # rare_fungi_target_burbank fixture; clear and re-add to be explicit.
      proj.project_target_locations.destroy_all
      proj.add_target_location(locations(:burbank))
      proj.update!(start_date: nil, end_date: nil, location: nil)
      proj.project_target_names.destroy_all
      elsewhere = observations(:falmouth_2023_09_obs)
      proj.add_observation(elsewhere)
      proj
    end
  end
end
