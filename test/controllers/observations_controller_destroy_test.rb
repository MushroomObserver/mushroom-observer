# frozen_string_literal: true

require("test_helper")

class ObservationsControllerDestroyTest < FunctionalTestCase
  tests ObservationsController

  ##############################################################################

  # -------------------- Destroy ---------------------------------------- #

  def test_destroy_observation
    assert(obs = observations(:minimal_unknown_obs))
    id = obs.id
    params = { id: id }
    assert_equal("mary", obs.user.login)
    requires_user(:destroy,
                  [{ action: :show }],
                  params, "mary")
    assert_redirected_to(action: :index)
    assert_raises(ActiveRecord::RecordNotFound) do
      obs = Observation.find(id)
    end
  end

  def test_destroy_observation_with_query_no_next
    # Test that destroying an observation when query has no next_id
    # redirects to index instead of crashing
    obs = observations(:minimal_unknown_obs)
    id = obs.id
    login("mary")

    # Create a query with just this one observation
    query = Query.lookup_and_save(:Observation, ids: [id])
    session[:checklist_source] = query.id.alphabetize

    delete(:destroy, params: { id: id })

    # Should redirect to index, not crash trying to show nil observation
    assert_redirected_to(action: :index)
    assert_raises(ActiveRecord::RecordNotFound) do
      Observation.find(id)
    end
  end

  # A read-only reflection is deletable by its owner like any other
  # observation -- it can always be reimported (#5180).
  def test_destroy_reflection_by_owner
    obs = observations(:imported_inat_obs)
    obs.update_column(:reflected_at, Time.zone.now)
    id = obs.id
    login(obs.user.login)

    assert_difference("Observation.count", -1) do
      delete(:destroy, params: { id: id })
    end
    assert_flash_success
    assert_raises(ActiveRecord::RecordNotFound) { Observation.find(id) }
  end

  # A non-owner gets the standard permission-denied path.
  def test_destroy_reflection_by_non_owner_is_permission_denied
    obs = observations(:imported_inat_obs)
    obs.update_column(:reflected_at, Time.zone.now)
    id = obs.id
    assert_not_equal("mary", obs.user.login, "mary must not own the obs")
    login("mary")

    assert_no_difference("Observation.count") do
      delete(:destroy, params: { id: id })
    end
    assert_flash_error
    assert_redirected_to(action: :show, id: id)
    assert(Observation.find(id).reflection?)
  end

  def test_original_filename_visibility
    login("mary")
    obs_id = observations(:agaricus_campestris_obs).id

    rolf.keep_filenames = "toss"
    rolf.save
    get(:show, params: { id: obs_id })
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_but_hide"
    rolf.save
    get(:show, params: { id: obs_id })
    assert_false(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_and_show"
    rolf.save
    get(:show, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))

    login("rolf") # owner

    rolf.keep_filenames = "toss"
    rolf.save
    get(:show, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_but_hide"
    rolf.save
    get(:show, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))

    rolf.keep_filenames = "keep_and_show"
    rolf.save
    get(:show, params: { id: obs_id })
    assert_true(@response.body.include?("áč€εиts"))
  end
end
