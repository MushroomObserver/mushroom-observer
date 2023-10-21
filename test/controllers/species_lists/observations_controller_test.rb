# frozen_string_literal: true

require("test_helper")

module SpeciesLists
  class ObservationsControllerTest < FunctionalTestCase
    def test_add_remove_observations
      query = Query.lookup(:Observation, :all, users: users(:mary))
      assert(query.num_results > 1)
      params = @controller.query_params(query) ## .merge(species_list: "")

      requires_login(:edit)
      assert_response(:redirect)
      assert_redirected_to(species_lists_path)
      assert_flash_error

      get(:edit, params: params)
      assert_response(:success)
      assert_input_value(:species_list, "")

      get(:edit, params: params.merge(species_list: "blah"))
      assert_response(:success)
      assert_input_value(:species_list, "blah")
    end

    def test_post_add_remove_observations
      query = Query.lookup(:Observation, :all, users: users(:mary))
      assert(query.num_results > 1)
      params = @controller.query_params(query)

      spl = species_lists(:unknown_species_list)
      old_count = spl.observations.size
      new_count = (spl.observations + query.results).uniq.count

      # make sure there are already some observations in list
      assert(old_count > 1)
      # make sure we are actually trying to add some observations!
      assert(new_count > old_count)
      # make sure some of the query results are already in there
      assert(query.results & spl.observations != [])

      # The form does not require any starting species_list or obs
      put_requires_login(:update)
      assert_response(:redirect)
      assert_redirected_to(
        edit_species_list_observations_path(species_list: "")
      )
      assert_flash_error
      assert_equal(old_count, spl.reload.observations.size)

      put(:update, params: params)
      assert_response(:redirect)
      assert_redirected_to(
        edit_species_list_observations_path(species_list: "")
      )
      assert_flash_error
      assert_equal(old_count, spl.reload.observations.size)

      put(:update, params: params.merge(species_list: "blah"))
      assert_response(:redirect)
      assert_redirected_to(
        edit_species_list_observations_path(species_list: "blah")
      )
      assert_flash_error
      assert_equal(old_count, spl.reload.observations.size)

      put(:update, params: { species_list: spl.title })
      assert_response(:redirect)
      assert_redirected_to(species_list_path(spl.id))
      assert_flash_error
      assert_equal(old_count, spl.reload.observations.size)

      put(:update, params: params.merge(species_list: spl.title))
      assert_response(:redirect)
      assert_redirected_to(species_list_path(spl.id))
      assert_flash_error
      assert_equal(old_count, spl.reload.observations.size)

      # Test a bogus commit param, in case of hacks
      put(:update,
          params: params.merge(commit: "bogus", species_list: spl.title))
      assert_response(:redirect)
      assert_redirected_to(%r{/species_lists})
      assert_flash_error
      assert_equal(old_count, spl.reload.observations.size)

      put(:update,
          params: params.merge(commit: :ADD.l, species_list: spl.title))
      assert_response(:redirect)
      assert_redirected_to(%r{/species_lists})
      assert_flash_error
      assert_equal(old_count, spl.reload.observations.size)

      login("mary")
      put(:update,
          params: params.merge(commit: :ADD.l, species_list: spl.title))
      assert_response(:redirect)
      assert_redirected_to(%r{/species_lists})
      assert_flash_success
      assert_equal(new_count, spl.reload.observations.size)

      put(:update,
          params: params.merge(commit: :REMOVE.l, species_list: spl.id.to_s))
      assert_response(:redirect)
      assert_redirected_to(%r{/species_lists})
      assert_flash_success
      assert_equal(0, spl.reload.observations.size)
    end

    def test_post_add_remove_double_observations
      spl = species_lists(:unknown_species_list)
      old_obs_list =
        SpeciesListObservation.select(:observation_id).
        where(species_list: spl.id).
        order(observation_id: :asc).
        map(&:observation_id)
      dup_obs = spl.observations.first
      new_obs = (Observation.all - spl.observations).first
      ids = [dup_obs.id, new_obs.id]
      query = Query.lookup(:Observation, :in_set, ids: ids)
      params = @controller.query_params(query).merge(
        commit: :ADD.l,
        species_list: spl.title
      )
      login(spl.user.login)
      put(:update, params: params)
      assert_response(:redirect)
      assert_flash_success
      new_obs_list =
        SpeciesListObservation.select(:observation_id).
        where(species_list: spl.id).
        order(observation_id: :asc).
        map(&:observation_id)
      assert_equal(new_obs_list.length, old_obs_list.length + 1)
      assert_equal((new_obs_list - old_obs_list).first, new_obs.id)
    end
  end
end
