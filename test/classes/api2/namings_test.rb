# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::NamingsTest < UnitTestCase
  include API2Extensions

  def test_basic_naming_get
    do_basic_get_test(Naming)
  end

  # ------------------------------
  #  :section: Naming Requests
  # ------------------------------

  def api2_model = Naming

  def test_getting_namings_id
    naming = namings(:coprinus_comatus_naming)
    assert_api_pass(params_get(id: naming.id))
    assert_api_results([naming])
  end

  def test_getting_namings_detail_high
    naming = namings(:coprinus_comatus_naming)
    assert_api_pass(params_get(id: naming.id, detail: :high))
    assert_equal(1, @api.results.length)
    assert_equal(naming.id, @api.results.first.id)
  end

  def test_getting_namings_by_observation
    obs = observations(:coprinus_comatus_obs)
    assert_not_empty(obs.namings)
    assert_api_pass(params_get(observation: obs.id))
    assert_api_results(obs.namings)
  end

  def test_getting_namings_by_user
    namings = Naming.where(user: mary)
    assert_not_empty(namings)
    assert_api_pass(params_get(user: "mary"))
    assert_api_results(namings)
  end

  def test_getting_namings_by_name
    name = names(:coprinus_comatus)
    namings = Naming.where(name: name)
    assert_not_empty(namings)
    assert_api_pass(params_get(name: name.id))
    assert_api_results(namings)
  end

  def test_creating_namings
    obs = observations(:detailed_unknown_obs)
    name = names(:agaricus_campestris)
    params = params_post(observation: obs.id, name: name.id)

    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:observation))
    assert_api_fail(params.except(:name))
    assert_api_pass(params)

    naming = obs.namings.find_by(name: name)
    assert_not_nil(naming, "Naming should have been created")
    assert_users_equal(rolf, naming.user)
    vote = naming.votes.find_by(user: rolf)
    assert_not_nil(vote, "Naming should get a Vote by default")
    assert_equal(Vote.maximum_vote, vote.value,
                 "Default vote should be maximum confidence")
    assert_equal(1, naming.votes.length)
    assert_not_nil(
      obs.rss_log&.notes&.match?(/log_naming_created/),
      "Naming creation should be logged to the observation's RSS log"
    )
  end

  def test_creating_namings_with_vote_and_reasons
    obs = observations(:detailed_unknown_obs)
    name = names(:agaricus_campestras)
    @reasons = { 1 => "Recognized it", 2 => nil, 3 => nil, 4 => nil }
    params = params_post(observation: obs.id, name: name.id,
                         vote: Vote.next_best_vote, reason_1: @reasons[1])
    assert_api_pass(params)

    naming = obs.namings.find_by(name: name)
    assert_not_nil(naming)
    vote = naming.votes.find_by(user: rolf)
    assert_in_delta(Vote.next_best_vote, vote.value, 0.01)
    assert_last_reasons_correct(naming)
  end

  def test_creating_namings_bad_vote
    obs = observations(:detailed_unknown_obs)
    name = names(:agaricus_campestros)
    params = params_post(observation: obs.id, name: name.id,
                         vote: Vote.maximum_vote + 1)
    assert_api_fail(params)
  end

  def test_updating_namings
    naming = namings(:agaricus_campestris_naming) # rolf, no votes yet
    new_name = names(:peltigera)
    @api_key.update!(user: naming.user)

    assert_api_fail(params_patch(id: naming.id))
    assert_api_pass(params_patch(id: naming.id, set_name: new_name.id))
    naming.reload
    assert_names_equal(new_name, naming.name)
  end

  def test_updating_namings_wrong_user
    naming = namings(:agaricus_campestrus_naming) # rolf, no votes yet
    @api_key.update!(user: mary)
    params = params_patch(id: naming.id, set_name: names(:peltigera).id)

    assert_api_fail(params)
    assert_names_equal(names(:agaricus_campestrus), naming.reload.name)
  end

  def test_updating_namings_locked
    naming = namings(:coprinus_comatus_naming) # mary has a positive vote
    @api_key.update!(user: naming.user)
    params = params_patch(id: naming.id, set_name: names(:peltigera).id)

    assert_api_fail(params)
    assert_names_equal(names(:coprinus_comatus), naming.reload.name)
  end

  def test_updating_namings_vote_by_any_user
    naming = namings(:agaricus_campestris_naming) # owned by rolf
    @api_key.update!(user: mary)
    params = params_patch(id: naming.id, set_vote: Vote.next_best_vote)

    assert_api_pass(params)
    vote = naming.votes.find_by(user: mary)
    assert_not_nil(
      vote, "Vote should be attributed to the caller, not the naming's owner"
    )
    assert_in_delta(Vote.next_best_vote, vote.value, 0.01)
  end

  def test_deleting_namings
    naming = namings(:agaricus_campestrus_naming) # rolf, no votes yet
    @api_key.update!(user: mary)
    params = params_delete(id: naming.id)

    assert_api_fail(params)
    assert_not_nil(Naming.safe_find(naming.id))

    @api_key.update!(user: naming.user)
    assert_api_pass(params)
    assert_nil(Naming.safe_find(naming.id))
  end

  def test_deleting_namings_locked
    naming = namings(:coprinus_comatus_naming) # mary has a positive vote
    @api_key.update!(user: naming.user)
    params = params_delete(id: naming.id)

    assert_api_fail(params)
    assert_not_nil(Naming.safe_find(naming.id))
  end
end
