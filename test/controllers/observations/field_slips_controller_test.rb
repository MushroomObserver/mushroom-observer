# frozen_string_literal: true

require("test_helper")

module Observations
  class FieldSlipsControllerTest < FunctionalTestCase
    def test_edit_renders_form
      obs = observations(:coprinus_comatus_obs)
      requires_login(:edit, id: obs.id)

      assert_response(:success)
      assert_select("form[action=?]", observation_field_slip_path(id: obs.id),
                    count: 1)
    end

    def test_edit_no_permission
      obs = observations(:coprinus_comatus_obs)
      login("mary")

      get(:edit, params: { id: obs.id })

      assert_redirected_to(permanent_observation_path(obs.id))
    end

    def test_attach_new_field_slip_code
      obs = observations(:coprinus_comatus_obs)
      assert_nil(obs.field_slip)
      code = "EOL-9999"
      assert_not(FieldSlip.exists?(code: code))

      login("rolf")
      put(:update, params: { id: obs.id, field_code: code })

      assert_redirected_to(permanent_observation_path(obs.id))
      assert_equal(code, obs.reload.field_slip&.code)
    end

    def test_attach_existing_field_slip_code
      obs = observations(:coprinus_comatus_obs)
      slip = field_slips(:field_slip_no_obs)
      assert_nil(obs.field_slip)
      assert_nil(slip.occurrence)

      login("rolf")
      put(:update, params: { id: obs.id, field_code: slip.code })

      assert_redirected_to(permanent_observation_path(obs.id))
      assert_flash_success
      assert_equal(slip.id, obs.reload.field_slip&.id)
    end

    def test_attach_invalid_field_slip_code
      obs = observations(:coprinus_comatus_obs)
      login("rolf")

      # All-numeric/period/dash codes fail FieldSlip's own format
      # validation (must have at least one non-numeric character).
      put(:update, params: { id: obs.id, field_code: "123-456" })

      assert_flash_error
      # Same-URL re-render needs non-2xx or Turbo hangs (see
      # .claude/rules/turbo_submit_forms.md).
      assert_unprocessable
      assert_nil(obs.reload.field_slip)
    end

    def test_update_no_permission
      obs = observations(:coprinus_comatus_obs)
      login("mary")

      put(:update, params: { id: obs.id, field_code: "EOL-9999" })

      assert_redirected_to(permanent_observation_path(obs.id))
      assert_nil(obs.reload.field_slip)
    end
  end
end
