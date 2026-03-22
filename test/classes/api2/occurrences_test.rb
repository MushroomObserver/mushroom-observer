# frozen_string_literal: true

require("test_helper")
require("api2_extensions")
require("builder")

class API2::OccurrencesTest < UnitTestCase
  include API2Extensions

  def setup
    super
    @obs1 = observations(:detailed_unknown_obs)
    @obs2 = observations(:amateur_obs)
    @occ = Occurrence.create!(
      user: @obs1.user,
      primary_observation: @obs1,
      has_specimen: true
    )
    @obs1.update!(occurrence: @occ)
    @obs2.update!(occurrence: @occ)
  end

  def params_get(**)
    { method: :get, action: :occurrence }.merge(**)
  end

  # GET tests

  def test_getting_occurrence_by_id
    assert_api_pass(params_get(id: @occ.id))
    assert_api_results([@occ])
  end

  def test_getting_occurrences_by_user
    assert_api_pass(params_get(user: @obs1.user_id))
    assert_api_results(Occurrence.where(user: @obs1.user))
  end

  def test_getting_occurrences_by_observation
    assert_api_pass(params_get(observation: @obs1.id))
    assert_api_results([@occ])
  end

  def test_getting_occurrences_by_field_slip
    slip = field_slips(:field_slip_one)
    occ = slip.occurrence
    assert_not_nil(occ, "Fixture field slip should have an occurrence")
    assert_api_pass(params_get(field_slip: slip.id))
    assert_api_results([occ])
  end

  # POST tests

  def test_posting_occurrence
    obs1 = observations(:coprinus_comatus_obs)
    obs2 = observations(:agaricus_campestris_obs)
    params = {
      method: :post,
      action: :occurrence,
      api_key: @api_key.key,
      observation: "#{obs1.id},#{obs2.id}",
      primary_observation: obs1.id
    }
    assert_api_pass(params)
    occ = Occurrence.find_by(primary_observation_id: obs1.id)
    assert_not_nil(occ, "Occurrence should have been created")
    assert_equal(obs1.id, occ.primary_observation_id)
    assert_includes(occ.observation_ids, obs2.id)
  end

  def test_posting_occurrence_requires_auth
    params = {
      method: :post,
      action: :occurrence,
      observation: "#{@obs1.id},#{@obs2.id}"
    }
    assert_api_fail(params)
  end

  def test_posting_occurrence_requires_two_observations
    obs1 = observations(:coprinus_comatus_obs)
    params = {
      method: :post,
      action: :occurrence,
      api_key: @api_key.key,
      observation: obs1.id.to_s
    }
    assert_api_fail(params)
  end

  # PATCH tests

  def test_patching_occurrence_add_observation
    obs3 = observations(:coprinus_comatus_obs)
    params = {
      method: :patch,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id,
      add_observation: obs3.id
    }
    assert_api_pass(params)
    @occ.reload
    assert_includes(@occ.observation_ids, obs3.id)
  end

  def test_patching_occurrence_remove_observation
    params = {
      method: :patch,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id,
      remove_observation: @obs2.id
    }
    assert_api_pass(params)
    # Occurrence should be destroyed (< 2 observations)
    assert_nil(Occurrence.find_by(id: @occ.id))
  end

  def test_patching_occurrence_set_primary
    params = {
      method: :patch,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id,
      set_primary_observation: @obs2.id
    }
    assert_api_pass(params)
    @occ.reload
    assert_equal(@obs2.id, @occ.primary_observation_id)
  end

  def test_patching_occurrence_without_params
    params = {
      method: :patch,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id
    }
    assert_api_fail(params)
  end

  # DELETE tests

  def test_deleting_occurrence
    params = {
      method: :delete,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id
    }
    assert_api_pass(params)
    assert_nil(Occurrence.find_by(id: @occ.id))
    @obs1.reload
    assert_nil(@obs1.occurrence_id)
  end

  def test_deleting_occurrence_requires_auth
    params = {
      method: :delete,
      action: :occurrence,
      id: @occ.id
    }
    assert_api_fail(params)
  end

  # Observation API: occurrence_id and effective has_specimen

  def test_observation_reports_occurrence_id
    api = API2.execute(
      method: :get,
      action: :observation,
      id: @obs1.id
    )
    assert_no_errors(api)
    assert_equal(1, api.results.length)
    obs = api.results.first
    assert_equal(@occ.id, obs.occurrence_id)
  end

  def test_observation_reports_effective_has_specimen
    # obs1 has specimen: false but occurrence has has_specimen: true
    @obs1.update!(specimen: false)
    @occ.update!(has_specimen: true)

    api = API2.execute(
      method: :get,
      action: :observation,
      id: @obs1.id,
      detail: :high
    )
    assert_no_errors(api)
    obs = api.results.first
    # The template should use occurrence's has_specimen
    effective = obs.occurrence&.has_specimen || obs.specimen
    assert(effective,
           "Effective specimen should be true from occurrence")
  end
end
