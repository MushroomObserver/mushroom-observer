# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::FieldSlipsTest < UnitTestCase
  include API2Extensions

  def test_basic_field_slip_get
    do_basic_get_test(FieldSlip)
  end

  # ---------------------------------------
  #  :section: Field Slip Requests
  # ---------------------------------------

  def params_get(**)
    { method: :get, action: :field_slip }.merge(**)
  end

  def test_getting_field_slips_by_code
    slip = field_slips(:field_slip_one)
    assert_api_pass(params_get(code: slip.code))
    assert_api_results([slip])
  end

  def test_getting_field_slips_code_has
    slips = FieldSlip.where(FieldSlip[:code].matches("%EOL%"))
    assert_not_empty(slips)
    assert_api_pass(params_get(code_has: "EOL"))
    assert_api_results(slips)
  end

  def test_getting_field_slips_by_observation
    obs = observations(:detailed_unknown_obs)
    slip = FieldSlip.create!(
      code: "TEST-#{rand(10_000)}",
      observation: obs,
      user: rolf
    )
    assert_api_pass(params_get(observation: obs.id))
    assert_api_results([slip])
  end

  def test_getting_field_slips_by_project
    project = projects(:eol_project)
    slips = FieldSlip.where(project: project)
    assert_not_empty(slips)
    assert_api_pass(params_get(project: project.id))
    assert_api_results(slips)
  end

  def test_getting_field_slips_by_user
    slips = FieldSlip.where(user: mary)
    assert_not_empty(slips)
    assert_api_pass(params_get(user: "mary"))
    assert_api_results(slips)
  end

  def test_posting_field_slip
    obs = observations(:detailed_unknown_obs)
    code = "NEMF-#{rand(100_000)}"
    params = {
      method: :post,
      action: :field_slip,
      api_key: @api_key.key,
      code: code,
      observation: obs.id
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:code))
    assert_api_pass(params)
    slip = FieldSlip.find_by(code: code)
    assert_not_nil(slip, "Field slip was not created")
    assert_equal(code.upcase, slip.code)
    assert_equal(obs.id, slip.observation_id)
  end

  def test_posting_field_slip_duplicate_code
    slip = field_slips(:field_slip_one)
    params = {
      method: :post,
      action: :field_slip,
      api_key: @api_key.key,
      code: slip.code
    }
    # Should fail because code already exists
    assert_api_fail(params)
  end

  def test_patching_field_slip
    slip = field_slips(:field_slip_one)
    new_code = "UPDATED-#{rand(100_000)}"
    params = {
      method: :patch,
      action: :field_slip,
      api_key: @api_key.key,
      id: slip.id,
      set_code: new_code
    }
    assert_api_pass(params)
    slip.reload
    assert_equal(new_code.upcase, slip.code)
  end

  def test_patching_field_slip_observation
    slip = field_slips(:field_slip_one)
    obs = observations(:detailed_unknown_obs)
    params = {
      method: :patch,
      action: :field_slip,
      api_key: @api_key.key,
      id: slip.id,
      set_observation: obs.id
    }
    assert_api_pass(params)
    slip.reload
    assert_equal(obs.id, slip.observation_id)
  end

  def test_field_slip_json_inline_helper
    slip = field_slips(:field_slip_one)
    helper = Object.new
    helper.extend(API2InlineHelper)

    result = helper.json_field_slip(slip)

    assert_equal(slip.id, result[:id])
    assert_equal(slip.code, result[:code])
  end

  def test_field_slip_renders_json
    slip = field_slips(:field_slip_one)
    params = {
      method: :get,
      action: :field_slip,
      id: slip.id,
      detail: :high
    }
    assert_api_pass(params)

    # Verify the API returns the slip without errors
    assert_equal(1, @api.results.length)
    assert_equal(slip.id, @api.results.first.id)
  end

  def test_field_slip_renders_xml
    slip = field_slips(:field_slip_one)
    params = {
      method: :get,
      action: :field_slip,
      id: slip.id,
      detail: :low
    }
    assert_api_pass(params)

    # Verify the API returns the slip without errors
    assert_equal(1, @api.results.length)
    assert_equal(slip.id, @api.results.first.id)
  end
end
