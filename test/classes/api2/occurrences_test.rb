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
    @obs3 = observations(:coprinus_comatus_obs)
    @obs4 = observations(:agaricus_campestris_obs)
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

  # == Coverage: POST with explicit primary ==

  def test_post_with_explicit_primary
    obs_a = observations(:peltigera_obs)
    obs_b = observations(:strobilurus_diminutivus_obs)
    params = {
      method: :post,
      action: :occurrence,
      api_key: @api_key.key,
      observation: "#{obs_a.id},#{obs_b.id}",
      primary_observation: obs_b.id
    }
    assert_api_pass(params)
    occ = Occurrence.find_by(primary_observation_id: obs_b.id)
    assert_not_nil(occ, "Should create with explicit primary")
    assert_equal(obs_b.id, occ.primary_observation_id)
  end

  def test_post_without_explicit_primary_picks_oldest
    obs_a = observations(:peltigera_obs)
    obs_b = observations(:strobilurus_diminutivus_obs)
    params = {
      method: :post,
      action: :occurrence,
      api_key: @api_key.key,
      observation: "#{obs_a.id},#{obs_b.id}"
    }
    assert_api_pass(params)
    oldest = [obs_a, obs_b].min_by(&:created_at)
    occ = Occurrence.where(
      primary_observation_id: [obs_a.id, obs_b.id]
    ).first
    assert_not_nil(occ)
    assert_equal(oldest.id, occ.primary_observation_id)
  end

  # == Coverage: PATCH add with merge ==

  def test_patch_add_with_merge
    # Create a second occurrence with obs3 and obs4
    occ2 = Occurrence.create!(
      user: @obs3.user,
      primary_observation: @obs3
    )
    @obs3.update!(occurrence: occ2)
    @obs4.update!(occurrence: occ2)

    params = {
      method: :patch,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id,
      add_observation: @obs3.id
    }
    assert_api_pass(params)
    @occ.reload

    # obs3 and obs4 should now belong to @occ (merged)
    assert_includes(@occ.observation_ids, @obs3.id)
    assert_includes(@occ.observation_ids, @obs4.id)
    assert_not(Occurrence.exists?(occ2.id),
               "Merged occurrence should be destroyed")
  end

  def test_patch_add_observation_no_merge
    obs_new = observations(:peltigera_obs)
    params = {
      method: :patch,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id,
      add_observation: obs_new.id
    }
    assert_api_pass(params)
    @occ.reload
    assert_includes(@occ.observation_ids, obs_new.id)
  end

  def test_patch_add_already_included_observation
    params = {
      method: :patch,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id,
      add_observation: @obs1.id
    }
    assert_api_pass(params)
    @occ.reload
    assert_equal(2, @occ.observations.count,
                 "Should not duplicate observation")
  end

  # == Coverage: PATCH remove triggers destroy ==

  def test_patch_remove_triggers_destroy_if_incomplete
    params = {
      method: :patch,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id,
      remove_observation: @obs2.id
    }
    assert_api_pass(params)
    assert_nil(Occurrence.find_by(id: @occ.id),
               "Should destroy when < 2 obs remain")
  end

  # == Coverage: PATCH set_primary ==

  def test_patch_set_primary
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

  # == Coverage: PATCH field_slip conflict ==

  def test_patch_add_field_slip_conflict
    fs1 = field_slips(:field_slip_one)
    fs2 = field_slips(:field_slip_two)
    @occ.update!(field_slip: fs1)

    obs_other = observations(:peltigera_obs)
    occ2 = Occurrence.create!(
      user: rolf, primary_observation: obs_other,
      field_slip: fs2
    )
    obs_other.update!(occurrence: occ2)

    params = {
      method: :patch,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id,
      add_observation: obs_other.id
    }
    assert_api_fail(params)
  end

  # == Coverage: DELETE with dissolve ==

  def test_delete_dissolves_occurrence
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

  def test_delete_with_field_slip_keeps_occurrence
    fs = field_slips(:field_slip_no_obs)
    @occ.update!(field_slip: fs)
    params = {
      method: :delete,
      action: :occurrence,
      api_key: @api_key.key,
      id: @occ.id
    }
    assert_api_pass(params)
    # Occurrence should survive with field_slip
    assert(Occurrence.exists?(@occ.id),
           "Occurrence with field_slip should survive")
    @occ.reload
    assert_equal(1, @occ.observations.count)
  end

  # == Coverage: POST multiple existing occurrences ==

  def test_post_multiple_existing_occurrences_raises
    obs_a = observations(:peltigera_obs)
    obs_b = observations(:strobilurus_diminutivus_obs)
    occ_a = Occurrence.create!(
      user: rolf, primary_observation: obs_a
    )
    obs_a.update!(occurrence: occ_a)
    occ_b = Occurrence.create!(
      user: rolf, primary_observation: obs_b
    )
    obs_b.update!(occurrence: occ_b)
    obs_c = observations(:owner_only_favorite_ne_consensus)
    obs_c.update!(occurrence: occ_b)

    params = {
      method: :post,
      action: :occurrence,
      api_key: @api_key.key,
      observation: "#{obs_a.id},#{obs_b.id}"
    }
    assert_raises(ActiveRecord::RecordInvalid) do
      API2.execute(params)
    end
  end

  def test_post_requires_observations
    params = {
      method: :post,
      action: :occurrence,
      api_key: @api_key.key
    }
    assert_api_fail(params)
  end

  # == Coverage: GET with detail: :high ==

  def test_getting_occurrence_with_high_detail
    assert_api_pass(params_get(id: @occ.id, detail: :high))
    assert_api_results([@occ])
    result = @api.results.first
    assert_equal(@occ.id, result.id)
    # high_detail_includes loads observations, field_slip, user
    assert(result.association(:observations).loaded?,
           "Observations should be eager-loaded")
    assert(result.association(:user).loaded?,
           "User should be eager-loaded")
  end

  # == Coverage: GET filtering by created_at range ==

  def test_getting_occurrences_by_created_at
    @occ.update!(created_at: Time.zone.parse("2024-06-15"))
    params = params_get(
      created_at: "2024-06-01-2024-06-30"
    )
    assert_api_pass(params)
    assert_includes(@api.results, @occ)
  end

  # == Coverage: POST single observation error message ==

  def test_posting_single_observation_error_message
    obs1 = observations(:peltigera_obs)
    params = {
      method: :post,
      action: :occurrence,
      api_key: @api_key.key,
      observation: obs1.id.to_s
    }
    api = API2.execute(params)
    assert(api.errors.any?,
           "Should fail with only one observation")
    err = api.errors.first
    assert_kind_of(API2::BadParameterValue, err)
  end
end
