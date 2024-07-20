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
