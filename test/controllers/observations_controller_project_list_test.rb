# frozen_string_literal: true

require("test_helper")

class ObservationsControllerProjectListTest < FunctionalTestCase
  tests ObservationsController

  def test_inital_project_checkboxes
    login("foray_newbie")
    get(:new)

    assert_project_checks(
      # open membership, meets date constrains
      projects(:current_project).id => :checked,
      # open-membership, doesn't meet date constraints
      projects(:past_project).id => :unchecked,
      # meets date constraints, but not a member
      projects(:eol_project).id => :no_field
    )
  end

  def test_field_slip_project_checkbox
    login("katrina")
    slip = field_slips(:field_slip_no_obs)
    get(:new, params: { field_code: slip.code })

    User.current.project_members.each do |membership|
      proj = membership.project
      if proj == slip.project || (proj.current? && proj.field_slip_prefix.nil?)
        assert_project_checks(proj.id => :checked)
      else
        assert_project_checks(proj.id => :unchecked)
      end
    end
  end

  def test_project_checkboxes_in_create_observation
    init_for_project_checkbox_tests

    login("dick")
    get(:new)
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)

    # Should have different default
    # if recently posted observation attached to project.
    obs = Observation.create!(user: dick)
    @proj2.add_observation(obs)
    get(:new)
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :checked)

    # Make sure it remember state of checks if submit fails.
    post(:create,
         params: {
           naming: { name: "Screwy Name" }, # (ensures it will fail)
           project: { "id_#{@proj1.id}" => "0" }
         })
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)
  end

  def test_project_checkboxes_in_update_observation
    init_for_project_checkbox_tests

    login("rolf")
    get(:edit, params: { id: @obs1.id })
    assert_response(:redirect)
    get(:edit, params: { id: @obs2.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
    put(
      :update,
      params: {
        id: @obs2.id,
        observation: {
          place_name: "blah blah blah", # (ensures it will fail)
          good_image_ids: @obs2_img_ids.join(" ") # necessary?
        },
        project: { "id_#{@proj1.id}" => "1" }
      }
    )
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    put(
      :update,
      params: {
        id: @obs2.id,
        observation: {
          good_image_ids: @obs2_img_ids.join(" ") # necessary?
        },
        project: { "id_#{@proj1.id}" => "1" }
      }
    )
    assert_response(:redirect)
    assert_obj_arrays_equal([@proj1], @obs2.reload.projects)
    assert_obj_arrays_equal([@proj1], @img2.reload.projects)

    login("mary")
    get(:edit, params: { id: @obs2.id })
    assert_project_checks(@proj1.id => :checked, @proj2.id => :unchecked)
    get(:edit, params: { id: @obs1.id })
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :checked)
    put(
      :update,
      params: {
        id: @obs1.id,
        observation: {
          place_name: "blah blah blah", # (ensures it will fail)
          good_image_ids: @obs1_img_ids.join(" ")
        },
        project: {
          "id_#{@proj1.id}" => "1",
          "id_#{@proj2.id}" => "0"
        }
      }
    )
    assert_project_checks(@proj1.id => :checked, @proj2.id => :unchecked)
    put(
      :update,
      params: {
        id: @obs1.id,
        observation: {
          good_image_ids: @obs1_img_ids.join(" ")
        },
        project: {
          "id_#{@proj1.id}" => "1",
          "id_#{@proj2.id}" => "1"
        }
      }
    )
    assert_response(:redirect)
    assert_obj_arrays_equal([@proj1, @proj2], @obs1.reload.projects, :sort)
    assert_obj_arrays_equal([@proj1, @proj2], @img1.reload.projects, :sort)

    login("dick")
    get(:edit, params: { id: @obs2.id })
    assert_response(:redirect)
    get(:edit, params: { id: @obs1.id })
    assert_project_checks(@proj1.id => :checked_but_disabled,
                          @proj2.id => :checked)
  end

  def init_for_project_checkbox_tests
    @proj1 = projects(:eol_project)
    @proj2 = projects(:bolete_project)
    @obs1 = observations(:detailed_unknown_obs)
    @obs2 = observations(:coprinus_comatus_obs)
    @obs1_imgs = @obs1.images
    @obs2_imgs = @obs2.images
    @img1 = @obs1_imgs.first
    @img2 = @obs2_imgs.first
    @obs1_img_ids = @obs1_imgs.map(&:id)
    @obs2_img_ids = @obs2_imgs.map(&:id)
  end

  def assert_project_checks(project_states)
    project_states.each do |id, state|
      assert_checkbox_state("project_id_#{id}", state)
    end
  end

  def test_project_observation_location
    project = projects(:albion_project)
    obs = observations(:california_obs)

    login("dick")
    put(
      :update,
      params: {
        id: obs.id,
        observation: { place_name: obs.place_name },
        project: { "id_#{project.id}" => "1" }
      }
    )
    assert_flash_warning
    assert_project_checks(project.id => :checked)
    put(
      :update,
      params: {
        id: obs.id,
        observation: { place_name: obs.place_name },
        project: {
          "id_#{project.id}" => "1",
          :ignore_proj_conflicts => "1"
        }
      }
    )
    assert_flash_warning
    assert_response(:redirect)
    assert_obj_arrays_equal([project], obs.reload.projects)
  end

  def test_no_warning_for_associated_projects
    project = projects(:albion_project)
    obs = observations(:california_obs)
    obs.projects << project
    obs.save!

    login("dick")
    put(
      :update,
      params: {
        id: obs.id,
        observation: { place_name: obs.place_name },
        project: { "id_#{project.id}" => "1" }
      }
    )
    assert_no_flash
    assert_response(:redirect)
  end

  def test_project_observation_good_location
    project = projects(:wrangel_island_project)
    obs = observations(:perkatkun_obs)

    login("dick")
    put(
      :update,
      params: {
        id: obs.id,
        observation: { place_name: obs.place_name },
        project: { "id_#{project.id}" => "1" }
      }
    )
    assert_response(:redirect)
    assert_obj_arrays_equal([project], obs.reload.projects)
  end

  def test_with_species_list
    init_for_list_checkbox_tests

    login("rolf")
    get(:new, params: { species_list: @spl1.id.to_s })
    assert_list_checks(@spl1.id => :checked)
  end

  def test_list_checkboxes_in_create_observation
    init_for_list_checkbox_tests

    login("rolf")
    get(:new)
    assert_list_checks(@spl1.id => :unchecked, @spl2.id => :no_field)

    login("mary")
    get(:new)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)

    login("katrina")
    get(:new)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :no_field)

    # Dick is on project that owns @spl2.
    login("dick")
    get(:new)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)

    # Should have different default
    # if recently posted observation attached to project.
    obs = Observation.create!(user: dick)
    @spl1.add_observation(obs) # (shouldn't affect anything for create)
    @spl2.add_observation(obs)
    get(:new)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :checked)

    # Make sure it remember state of checks if submit fails.
    post(
      :create,
      params: {
        naming: { name: "Screwy Name" }, # (ensures it will fail)
        list: { "id_#{@spl2.id}" => "0" }
      }
    )
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)
  end

  def test_edit_observation_form_no_open
    obs = observations(:amateur_obs)
    project = projects(:open_membership_project)
    login("katrina")
    get(:edit, params: { id: obs.id })
    assert_project_checks(project.id => :unchecked)
  end

  def test_list_checkboxes_in_update_observation
    init_for_list_checkbox_tests

    login("rolf")
    get(:edit, params: { id: @obs1.id })
    assert_list_checks(@spl1.id => :unchecked, @spl2.id => :no_field)
    spl_start_length = @spl1.observations.length
    put(
      :update,
      params: {
        id: @obs1.id,
        observation: { place_name: "blah blah blah" }, # (ensures it will fail)
        list: { "id_#{@spl1.id}" => "1" }
      }
    )
    assert_equal(spl_start_length, @spl1.reload.observations.length)
    assert_list_checks(@spl1.id => :checked, @spl2.id => :no_field)
    put(
      :update,
      params: {
        id: @obs1.id,
        list: { "id_#{@spl1.id}" => "1" }
      }
    )
    assert_equal(spl_start_length + 1, @spl1.reload.observations.length)
    assert_response(:redirect)
    assert_obj_arrays_equal([@spl1], @obs1.reload.species_lists)
    get(:edit, params: { id: @obs2.id })
    assert_response(:redirect)

    login("mary")
    get(:edit, params: { id: @obs1.id })
    assert_response(:redirect)
    get(:edit, params: { id: @obs2.id })
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :checked)
    @spl1.add_observation(@obs2)
    get(:edit, params: { id: @obs2.id })
    assert_list_checks(@spl1.id => :checked_but_disabled, @spl2.id => :checked)

    login("dick")
    get(:edit, params: { id: @obs2.id })
    assert_list_checks(@spl1.id => :checked_but_disabled, @spl2.id => :checked)
  end

  def init_for_list_checkbox_tests
    @spl1 = species_lists(:first_species_list)
    @spl2 = species_lists(:unknown_species_list)
    @obs1 = observations(:unlisted_rolf_obs)
    @obs2 = observations(:detailed_unknown_obs)
    assert_users_equal(rolf, @spl1.user)
    assert_users_equal(mary, @spl2.user)
    assert_users_equal(rolf, @obs1.user)
    assert_users_equal(mary, @obs2.user)
    assert_obj_arrays_equal([], @obs1.species_lists)
    assert_obj_arrays_equal([@spl2], @obs2.species_lists)
  end

  def assert_list_checks(list_states)
    list_states.each do |id, state|
      assert_checkbox_state("list_id_#{id}", state)
    end
  end
end
