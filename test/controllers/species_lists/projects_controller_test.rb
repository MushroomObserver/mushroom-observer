# frozen_string_literal: true

require("test_helper")

module SpeciesLists
  class ProjectsControllerTest < FunctionalTestCase
    # ----------------------------
    #  Project Manager.
    # ----------------------------

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
          objects_list: "1",
          objects_obs: "1",
          objects_img: "0",
          "projects_#{proj.id}" => "1",
          commit: :REMOVE.l
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
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj.id}" => "1",
          commit: :ATTACH.l
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
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj.id}" => "1",
          commit: :ATTACH.l
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
      assert_checkbox_state("objects_list", :unchecked)
      assert_checkbox_state("objects_obs", :unchecked)
      assert_checkbox_state("objects_img", :unchecked)
      assert_checkbox_state("projects_#{proj1.id}", :no_field)
      assert_checkbox_state("projects_#{proj2.id}", :unchecked)

      login("mary")
      get(:edit, params: { id: list.id })
      assert_checkbox_state("objects_list", :unchecked)
      assert_checkbox_state("objects_obs", :unchecked)
      assert_checkbox_state("objects_img", :unchecked)
      assert_checkbox_state("projects_#{proj1.id}", :unchecked)
      assert_checkbox_state("projects_#{proj2.id}", :unchecked)

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "0",
          commit: "bogus"
        }
      )
      assert_flash_error # bogus commit button
      assert_obj_arrays_equal([proj2], list.projects.reload)

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "0",
          commit: :ATTACH.l
        }
      )
      assert_flash_warning # no changes
      assert_obj_arrays_equal([proj2], list.projects.reload)

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "1",
          commit: :ATTACH.l
        }
      )
      assert_flash_warning # no changes
      assert_obj_arrays_equal([proj2], list.projects.reload)

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj1.id}" => "1",
          "projects_#{proj2.id}" => "0",
          commit: :ATTACH.l
        }
      )
      assert_flash_success
      assert_obj_arrays_equal([proj1, proj2], list.projects.reload, :sort)

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj1.id}" => "1",
          "projects_#{proj2.id}" => "0",
          commit: :ATTACH.l
        }
      )
      assert_flash_warning # already attached
      assert_obj_arrays_equal([proj1, proj2], list.projects.reload, :sort)

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "0",
          commit: :REMOVE.l
        }
      )
      assert_flash_warning # no changes
      assert_obj_arrays_equal([proj1, proj2], list.projects.reload, :sort)

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "1",
          commit: :REMOVE.l
        }
      )
      assert_flash_success
      assert_obj_arrays_equal([proj1], list.projects.reload)

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "1",
          commit: :REMOVE.l
        }
      )
      assert_flash_warning # no changes
      assert_obj_arrays_equal([proj1], list.projects.reload)

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "1",
          objects_obs: "0",
          objects_img: "0",
          "projects_#{proj1.id}" => "1",
          "projects_#{proj2.id}" => "0",
          commit: :REMOVE.l
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
          objects_list: "0",
          objects_obs: "1",
          objects_img: "1",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "0",
          commit: :ATTACH.l
        }
      )
      assert_flash_warning # no changes

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "0",
          objects_obs: "1",
          objects_img: "1",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "0",
          commit: :REMOVE.l
        }
      )
      assert_flash_warning # no changes

      put(
        :update,
        params: {
          id: list.id,
          objects_list: "0",
          objects_obs: "1",
          objects_img: "1",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "1",
          commit: :ATTACH.l
        }
      )
      assert_flash_success # no permission

      login("dick")
      put(
        :update,
        params: {
          id: list.id,
          objects_list: "0",
          objects_obs: "1",
          objects_img: "1",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "1",
          commit: :ATTACH.l
        }
      )
      assert_flash_warning # already done

      login("mary")
      put(
        :update,
        params: {
          id: list.id,
          objects_list: "0",
          objects_obs: "1",
          objects_img: "1",
          "projects_#{proj1.id}" => "1",
          "projects_#{proj2.id}" => "",
          commit: :ATTACH.l
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
          objects_list: "0",
          objects_obs: "1",
          objects_img: "1",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "1",
          commit: :REMOVE.l
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
          objects_list: "0",
          objects_obs: "1",
          objects_img: "1",
          "projects_#{proj1.id}" => "0",
          "projects_#{proj2.id}" => "1",
          commit: :REMOVE.l
        }
      )
      assert_flash_warning # already done
    end
  end
end
