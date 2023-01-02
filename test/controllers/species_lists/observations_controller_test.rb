# frozen_string_literal: true

require("test_helper")

module SpeciesLists
  class ObservationsControllerTest < FunctionalTestCase
    def test_manage_species_lists
      obs = observations(:coprinus_comatus_obs)
      params = { id: obs.id.to_s }
      requires_login(:manage_species_lists, params: params)

      assert(assigns_exist, "Missing species lists!")
    end

    def test_add_observation_to_species_list
      sp = species_lists(:first_species_list)
      obs = observations(:coprinus_comatus_obs)
      assert_not(sp.observations.member?(obs))
      params = { species_list: sp.id, observation: obs.id }
      requires_login(:add_observation_to_species_list, params)
      assert_redirected_to(action: :manage_species_lists, id: obs.id)
      assert(sp.reload.observations.member?(obs))
    end

    def test_add_observation_to_species_list_no_permission
      sp = species_lists(:first_species_list)
      obs = observations(:coprinus_comatus_obs)
      assert_not(sp.observations.member?(obs))
      params = { species_list: sp.id, observation: obs.id }
      login("dick")
      get(:add_observation_to_species_list, params: params)
      assert_redirected_to(species_list_path(sp.id))
      assert_not(sp.reload.observations.member?(obs))
    end

    def test_remove_observation_from_species_list
      spl = species_lists(:unknown_species_list)
      obs = observations(:minimal_unknown_obs)
      assert(spl.observations.member?(obs))
      params = { species_list: spl.id, observation: obs.id }
      owner = spl.user.login
      assert_not_equal("rolf", owner)

      # Try with non-owner (can't use requires_user since failure is a redirect)
      # effectively fails and gets redirected to show_species_list
      requires_login(:remove_observation_from_species_list, params)
      assert_redirected_to(species_list_path(spl.id))
      assert(spl.reload.observations.member?(obs))

      login(owner)
      get(:remove_observation_from_species_list, params: params)
      assert_redirected_to(action: "manage_species_lists", id: obs.id)
      assert_not(spl.reload.observations.member?(obs))
    end

    def test_manage_species_list_with_projects
      proj = projects(:bolete_project)
      spl1 = species_lists(:unknown_species_list)
      spl2 = species_lists(:first_species_list)
      spl3 = species_lists(:another_species_list)
      spl2.user = dick
      spl2.save
      spl2.reload
      obs1 = observations(:detailed_unknown_obs)
      obs2 = observations(:coprinus_comatus_obs)
      assert_obj_list_equal([dick], proj.user_group.users)
      assert_obj_list_equal([proj], spl1.projects)
      assert_obj_list_equal([], spl2.projects)
      assert_obj_list_equal([], spl3.projects)
      assert_true(spl1.observations.include?(obs1))
      assert_false(spl1.observations.include?(obs2))
      assert_obj_list_equal([], spl2.observations)
      assert_obj_list_equal([], spl3.observations)
      assert_users_equal(mary, spl1.user)
      assert_users_equal(dick, spl2.user)
      assert_users_equal(rolf, spl3.user)

      login("dick")
      get(:manage_species_lists, params: { id: obs1.id })
      assert_select("a[href*='species_list=#{spl1.id}']",
                    text: :REMOVE.t, count: 1)
      assert_select("a[href*='species_list=#{spl2.id}']", text: :ADD.t,
                                                          count: 1)
      assert_select("a[href*='species_list=#{spl3.id}']", count: 0)

      get(:manage_species_lists, params: { id: obs2.id })
      assert_select("a[href*='species_list=#{spl1.id}']", text: :ADD.t,
                                                          count: 1)
      assert_select("a[href*='species_list=#{spl2.id}']", text: :ADD.t,
                                                          count: 1)
      assert_select("a[href*='species_list=#{spl3.id}']", count: 0)

      post(:add_observation_to_species_list,
           params: { observation: obs2.id,
                     species_list: spl1.id })
      assert_redirected_to(action: :manage_species_lists, id: obs2.id)
      assert_true(spl1.reload.observations.include?(obs2))

      post(:remove_observation_from_species_list,
           params: { observation: obs2.id,
                     species_list: spl1.id })
      assert_redirected_to(action: :manage_species_lists, id: obs2.id)
      assert_false(spl1.reload.observations.include?(obs2))
    end
  end
end
