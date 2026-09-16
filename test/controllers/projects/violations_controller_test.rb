# frozen_string_literal: true

require("test_helper")

# Functional tests for Projects::ViolationsController. The page is keyed
# off Project::VIOLATION_KINDS (#4136); this exercises rendering and
# the four PUT actions (exclude, extend, add_target_name,
# add_target_location) plus back-compat for the legacy
# "Remove Selected" form.
module Projects
  class ViolationsControllerTest < FunctionalTestCase
    def test_index_renders_for_owner
      project = projects(:falmouth_2023_09_project)
      violations = project.violations
      assert(violations.any?,
             "Test needs Project fixture with violations")

      user = project.user
      login(user.login)
      get(:index, params: { id: project.id })

      assert_response(:success)
      assert_select("#content", { text: /#{project.title}/ })
      assert_select("a[href = '#{project_path(project)}']", true,
                    "Missing project link")
      violations.each do |v|
        assert_select("a[href*='#{v.obs.id}']", { count: 1 },
                      "Missing obs link for #{v.obs.id}")
      end
    end

    # Overrides the `controller_name.classify` default (which would
    # derive "Violation", not a model). Nothing else exercises this:
    # TopNav's create-button label and Sorter's sort-link name both
    # call it, but neither renders on this controller's pages (no
    # `new` action, no sortable Query).
    def test_controller_model_name
      assert_equal("Project", @controller.controller_model_name)
    end

    def test_index_no_violations
      project = projects(:eol_project)
      assert_empty(project.violations,
                   "Test needs project with no violations")

      login(project.user.login)
      get(:index, params: { id: project.id })

      assert_response(:success)
      assert_select("p", { text: /#{:form_violations_no_violations.l}/ })
    end

    # @pagination_data.num_total must reflect the full violation
    # count, not just the first page's worth.
    def test_index_pagination_data_matches_full_violation_count
      project = projects(:falmouth_2023_09_project)
      login(project.user.login)
      get(:index, params: { id: project.id })

      assert_response(:success)
      pagination_data = @controller.instance_variable_get(:@pagination_data)
      assert_equal(project.violations.size, pagination_data.num_total)
    end

    # An obs link's q: must resolve to the violations query, not an
    # unfiltered/unrelated one, or prev/next from that obs won't stay
    # within this project's violations.
    def test_index_obs_links_carry_violations_query
      project = projects(:falmouth_2023_09_project)
      login(project.user.login)

      get(:index, params: { id: project.id })

      assert_response(:success)
      encoded = CGI.escape("q[project_violations]")
      assert_select(
        "a[href*='#{encoded}=#{project.id}']",
        { minimum: 1 },
        "Obs links should carry q: for the stored violations query"
      )
    end

    # Visiting the violations page stores a Query for this project's
    # violations, replacing whatever was stored before -- same as
    # any other index page. This is what lets prev/next from a
    # violation's obs page stay within this project's violations
    # instead of falling back to the stale query.
    def test_index_stores_violations_query_in_session
      project = projects(:falmouth_2023_09_project)
      login(project.user.login)
      other_query = Query.lookup_and_save(:Project, by_users: project.user.id)
      session[:query_record] = other_query.id

      get(:index, params: { id: project.id })

      assert_response(:success)
      assert_not_equal(other_query.id, session[:query_record],
                       "Visiting the violations page should replace an " \
                       "unrelated stored query with the violations query")
      stored = Query.safe_find(session[:query_record])
      assert_not_nil(stored)
      assert_equal(project.id, stored.params[:project_violations])
    end

    # Pagination here is manual LIMIT/OFFSET on @project.violating_
    # observations, not the stored Query's paginate/clamp machinery,
    # so an out-of-range page has no page-clamp mechanism to trigger
    # -- it renders empty instead of redirecting.
    def test_index_large_page_number_does_not_redirect
      project = projects(:falmouth_2023_09_project)
      login(project.user.login)
      get(:index, params: { id: project.id, page: 999 })

      assert_response(:success)
    end

    def test_update_legacy_remove_selected
      project = projects(:falmouth_2023_09_project)
      victim = project.violations.first.obs
      params = { id: project.id,
                 project: { "remove_#{victim.id}" => "1" } }

      login(project.user.login)
      assert_difference("project.observations.count", -1) do
        put(:update, params: params)
      end
      assert_not_includes(project.observations, victim)
    end

    def test_update_exclude
      project = projects(:falmouth_2023_09_project)
      victim = project.violations.first.obs
      params = { id: project.id,
                 project: { do: "exclude", obs_id: victim.id } }

      login(project.user.login)
      put(:update, params: params)

      assert_redirected_to(project_violations_path(project.id))
      assert_includes(project.excluded_observations, victim)
      assert_not_includes(project.observations, victim)
    end

    def test_update_extend_widens_dates
      project = projects(:falmouth_2023_09_project)
      future_violation =
        project.violations.find { |v| v.kinds.include?(:date) }
      assert(future_violation, "Test needs a date violation in fixtures")
      victim = future_violation.obs
      params = { id: project.id,
                 project: { do: "extend", obs_id: victim.id } }

      login(project.user.login)
      put(:update, params: params)

      project.reload
      assert(project.start_date.nil? || project.start_date <= victim.when)
      assert(project.end_date.nil? || project.end_date >= victim.when)
    end

    def test_update_add_target_name
      proj = projects(:rare_fungi_project)
      proj.project_target_names.destroy_all
      proj.add_target_name(names(:agaricus))
      proj.update!(start_date: nil, end_date: nil, location: nil)
      proj.project_target_locations.destroy_all
      off_target = observations(:peltigera_obs)
      proj.add_observation(off_target)

      params = { id: proj.id,
                 project: { do: "add_target_name",
                            obs_id: off_target.id } }
      login(proj.user.login)
      put(:update, params: params)

      assert_redirected_to(project_violations_path(proj.id))
      assert_includes(proj.target_names.reload, off_target.name)
    end

    def test_update_add_target_location
      proj = projects(:rare_fungi_project)
      proj.project_target_locations.destroy_all
      proj.add_target_location(locations(:burbank))
      proj.update!(start_date: nil, end_date: nil, location: nil)
      proj.project_target_names.destroy_all
      elsewhere = observations(:falmouth_2023_09_obs)
      proj.add_observation(elsewhere)
      new_target = locations(:falmouth)

      params = { id: proj.id,
                 project: { do: "add_target_location",
                            obs_id: elsewhere.id,
                            location_id: new_target.id } }
      login(proj.user.login)
      put(:update, params: params)

      assert_redirected_to(project_violations_path(proj.id))
      assert_includes(proj.target_locations.reload, new_target)
    end

    def test_update_admin_only_actions_no_op_for_non_admin
      proj = projects(:falmouth_2023_09_project)
      stranger = users(:zero_user)
      assert_not(proj.is_admin?(stranger))
      original_start = proj.start_date
      original_end = proj.end_date
      victim = proj.violations.first.obs

      login(stranger.login)
      put(:update, params: { id: proj.id,
                             project: { do: "extend",
                                        obs_id: victim.id } })

      proj.reload
      assert_equal(original_start, proj.start_date,
                   "Non-admin should not be able to extend project dates")
      assert_equal(original_end, proj.end_date)
    end

    def test_update_exclude_by_obs_owner
      proj = projects(:falmouth_2023_09_project)
      victim = proj.violations.first.obs

      login(victim.user.login)
      put(:update, params: { id: proj.id,
                             project: { do: "exclude",
                                        obs_id: victim.id } })

      assert_redirected_to(project_violations_path(proj.id))
      assert_includes(proj.excluded_observations, victim,
                      "Obs owner can self-exclude their own violation")
    end

    def test_update_exclude_by_stranger_is_forbidden
      proj = projects(:falmouth_2023_09_project)
      victim = proj.violations.first.obs
      stranger = users(:zero_user)
      assert_not_equal(stranger, victim.user)
      assert_not(proj.is_admin?(stranger))

      login(stranger.login)
      put(:update, params: { id: proj.id,
                             project: { do: "exclude",
                                        obs_id: victim.id } })

      assert_not_includes(proj.excluded_observations, victim,
                          "Stranger cannot exclude someone else's obs")
    end

    def test_update_nonexistent_project
      id = -1
      params = { id: id,
                 project: { do: "exclude", obs_id: 0 } }
      login
      put(:update, params: params)
      assert_redirected_to(projects_path)
    end

    # ---------- target_location_modal endpoint (#4304) ----------

    def test_target_location_modal_renders_for_admin
      project = projects(:rare_fungi_project)
      project.project_target_locations.destroy_all
      project.add_target_location(locations(:burbank))
      project.update!(start_date: nil, end_date: nil, location: nil)
      project.add_observation(observations(:falmouth_2023_09_obs))
      obs = observations(:falmouth_2023_09_obs)

      login(project.user.login)
      get(:target_location_modal,
          params: { id: project.id, obs_id: obs.id },
          format: :turbo_stream)

      assert_response(:success)
      modal_id = Views::Controllers::Projects::Violations::TargetLocationForm.modal_id_for(obs)
      # form-content branch — obs has usable suffixes, so the modal
      # renders the TargetLocationForm with body+footer inside <form>.
      assert_select("##{modal_id}", { count: 1 },
                    "Endpoint must render the Add-Target-Location modal")
      assert_select("##{modal_id} form > .modal-body", { count: 1 })
      assert_select("##{modal_id} form > .modal-footer", { count: 1 })
      assert_select("##{modal_id} form[data-turbo='true']", { count: 1 })
      assert_select(
        "##{modal_id} input[type=hidden][name='project[do]']" \
        "[value=add_target_location]",
        { count: 1 }
      )
      assert_select(
        "##{modal_id} input[type=hidden][name='project[obs_id]']" \
        "[value='#{obs.id}']",
        { count: 1 }
      )
    end

    # No-usable-suffixes branch (country-only `where`) — the modal
    # renders a static body + Cancel-only footer instead of a form.
    # Folded into the controller test (per #4300's pattern of moving
    # one-controller-action modal coverage to its controller test)
    # after `Components::TargetLocationModal` moved to
    # `Views::Controllers::Projects::Violations::TargetLocationModal`.
    def test_target_location_modal_renders_no_suffixes_branch
      project = projects(:rare_fungi_project)
      project.project_target_locations.destroy_all
      project.add_target_location(locations(:burbank))
      project.update!(start_date: nil, end_date: nil, location: nil)
      obs = observations(:falmouth_2023_09_obs)
      obs.update!(location_id: nil, where: "USA")
      project.add_observation(obs)

      login(project.user.login)
      get(:target_location_modal,
          params: { id: project.id, obs_id: obs.id },
          format: :turbo_stream)

      assert_response(:success)
      modal_id = Views::Controllers::Projects::Violations::TargetLocationForm.modal_id_for(obs)
      assert_select(
        "##{modal_id} .modal-body p",
        { text: :form_violations_modal_target_location_no_suffixes.l }
      )
      assert_select(
        "##{modal_id} .modal-footer button[data-dismiss=modal]",
        { text: :cancel.ti }
      )
      assert_select("##{modal_id} form", { count: 0 },
                    "No form when there's nothing to submit")
    end

    def test_target_location_modal_404s_for_non_admin
      project = projects(:rare_fungi_project)
      obs = observations(:falmouth_2023_09_obs)

      login(users(:mary).login) # not admin of rare_fungi_project
      get(:target_location_modal,
          params: { id: project.id, obs_id: obs.id },
          format: :turbo_stream)

      assert_response(:not_found)
    end

    def test_target_location_modal_404s_for_missing_obs
      project = projects(:rare_fungi_project)
      login(project.user.login)
      get(:target_location_modal,
          params: { id: project.id, obs_id: -1 },
          format: :turbo_stream)

      assert_response(:not_found)
    end

    def test_target_location_modal_404s_for_missing_project
      obs = observations(:falmouth_2023_09_obs)
      login(users(:rolf).login)
      get(:target_location_modal,
          params: { id: -1, obs_id: obs.id },
          format: :turbo_stream)

      assert_response(:not_found)
    end
  end
end
