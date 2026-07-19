# frozen_string_literal: true

require("test_helper")

module SpeciesLists
  class ProjectsControllerTest < FunctionalTestCase
    # ----------------------------
    #  Project Manager.
    # ----------------------------

    # Helper: CSS selector for the array-mode checkbox input of a
    # specific project under the `species_list_projects[project_ids][]`
    # name.
    def project_checkbox_selector(proj)
      "input[name='species_list_projects[project_ids][]']" \
        "[value='#{proj.id}']"
    end

    def test_manage_projects_permission
      list = species_lists(:unknown_species_list)

      # Requires login.
      get(:edit, params: { id: list.id })
      assert_response(:redirect)

      # Must have permission to edit list.
      login("rolf")
      get(:edit, params: { id: list.id })
      assert_response(:redirect)

      # Members of group that has list are good enough.
      login("dick")
      get(:edit, params: { id: list.id })
      assert_response(:success)

      # Owner of list always can.
      login("mary")
      get(:edit, params: { id: list.id })
      assert_response(:success)
    end

    def test_dont_remove_unowned_obs
      list = species_lists(:reused_list)
      proj = projects(:open_membership_project)
      obs = proj.observations

      login("mary")
      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "1",
            objects_img: "0",
            project_ids: [proj.id.to_s]
          },
          commit: :remove.ti
        }
      )
      proj.reload
      assert_equal(obs, proj.observations)
    end

    def test_reused_list
      list = species_lists(:reused_list)
      proj = projects(:open_membership_project)

      login("mary")
      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: [proj.id.to_s]
          },
          commit: :attach.ti
        }
      )
      assert_flash_error
    end

    def test_unowned_list
      proj = projects(:eol_project)
      list = species_lists(:lone_wolf_list)

      login("mary")
      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: [proj.id.to_s]
          },
          commit: :attach.ti
        }
      )
      assert_response(:redirect)
    end

    def test_manage_projects_list
      proj1 = projects(:eol_project)
      proj2 = projects(:bolete_project)
      list = species_lists(:unknown_species_list)

      login("dick")
      get(:edit, params: { id: list.id })
      assert_checkbox_state("species_list_projects_objects_list", :unchecked)
      assert_checkbox_state("species_list_projects_objects_obs", :unchecked)
      assert_checkbox_state("species_list_projects_objects_img", :unchecked)
      # Project checkboxes are array-mode; select by name+value.
      assert_select(project_checkbox_selector(proj1), count: 0)
      assert_select(project_checkbox_selector(proj2), count: 1)
      assert_select("#{project_checkbox_selector(proj2)}[checked]", count: 0)

      login("mary")
      get(:edit, params: { id: list.id })
      assert_checkbox_state("species_list_projects_objects_list", :unchecked)
      assert_checkbox_state("species_list_projects_objects_obs", :unchecked)
      assert_checkbox_state("species_list_projects_objects_img", :unchecked)
      assert_select(project_checkbox_selector(proj1), count: 1)
      assert_select("#{project_checkbox_selector(proj1)}[checked]", count: 0)
      assert_select(project_checkbox_selector(proj2), count: 1)
      assert_select("#{project_checkbox_selector(proj2)}[checked]", count: 0)

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: []
          },
          commit: "bogus"
        }
      )
      assert_flash_error # bogus commit button
      assert_obj_arrays_equal([proj2], list.projects.reload)

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: []
          },
          commit: :attach.ti
        }
      )
      assert_flash_warning # no changes
      assert_obj_arrays_equal([proj2], list.projects.reload)

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: [proj2.id.to_s]
          },
          commit: :attach.ti
        }
      )
      assert_flash_warning # no changes
      assert_obj_arrays_equal([proj2], list.projects.reload)

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: [proj1.id.to_s]
          },
          commit: :attach.ti
        }
      )
      assert_flash_success
      assert_obj_arrays_equal([proj1, proj2], list.projects.reload, :sort)

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: [proj1.id.to_s]
          },
          commit: :attach.ti
        }
      )
      assert_flash_warning # already attached
      assert_obj_arrays_equal([proj1, proj2], list.projects.reload, :sort)

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: []
          },
          commit: :remove.ti
        }
      )
      assert_flash_warning # no changes
      assert_obj_arrays_equal([proj1, proj2], list.projects.reload, :sort)

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: [proj2.id.to_s]
          },
          commit: :remove.ti
        }
      )
      assert_flash_success
      assert_obj_arrays_equal([proj1], list.projects.reload)

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: [proj2.id.to_s]
          },
          commit: :remove.ti
        }
      )
      assert_flash_warning # no changes
      assert_obj_arrays_equal([proj1], list.projects.reload)

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "1",
            objects_obs: "0",
            objects_img: "0",
            project_ids: [proj1.id.to_s]
          },
          commit: :remove.ti
        }
      )
      assert_flash_success
      assert_obj_arrays_equal([], list.projects.reload)
    end

    def test_manage_projects_obs_and_img
      proj1 = projects(:eol_project)
      proj2 = projects(:bolete_project)
      list = species_lists(:unknown_species_list)
      proj1_obs_length = proj1.observations.length
      proj1_images_length = proj1.images.length

      login("mary")
      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "0",
            objects_obs: "1",
            objects_img: "1",
            project_ids: []
          },
          commit: :attach.ti
        }
      )
      assert_flash_warning # no changes

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "0",
            objects_obs: "1",
            objects_img: "1",
            project_ids: []
          },
          commit: :remove.ti
        }
      )
      assert_flash_warning # no changes

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "0",
            objects_obs: "1",
            objects_img: "1",
            project_ids: [proj2.id.to_s]
          },
          commit: :attach.ti
        }
      )
      assert_flash_success # no permission

      login("dick")
      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "0",
            objects_obs: "1",
            objects_img: "1",
            project_ids: [proj2.id.to_s]
          },
          commit: :attach.ti
        }
      )
      assert_flash_warning # already done

      login("mary")
      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "0",
            objects_obs: "1",
            objects_img: "1",
            project_ids: [proj1.id.to_s]
          },
          commit: :attach.ti
        }
      )
      assert_flash_success
      proj1.reload
      assert_equal(proj1_obs_length + 2, proj1.observations.length)
      assert_equal(proj1_images_length + 2, proj1.images.length)

      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "0",
            objects_obs: "1",
            objects_img: "1",
            project_ids: [proj2.id.to_s]
          },
          commit: :remove.ti
        }
      )
      assert_flash_success
      proj2.reload
      assert_equal(0, proj2.observations.length)
      assert_equal(0, proj2.images.length)

      login("dick")
      put(
        :update,
        params: {
          id: list.id,
          species_list_projects: {
            objects_list: "0",
            objects_obs: "1",
            objects_img: "1",
            project_ids: [proj2.id.to_s]
          },
          commit: :remove.ti
        }
      )
      assert_flash_warning # already done
    end
  end
end
