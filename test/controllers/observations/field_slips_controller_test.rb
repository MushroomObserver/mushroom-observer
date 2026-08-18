# frozen_string_literal: true

require("test_helper")

module Observations
  class FieldSlipsControllerTest < FunctionalTestCase
    def test_edit_renders_form
      obs = observations(:coprinus_comatus_obs)
      requires_login(:edit, id: obs.id)

      assert_response(:success)
      # method="put"/"patch" isn't valid HTML5 -- a real browser would
      # submit as GET (no matching route) unless the form spoofs the
      # method via a hidden _method field on an actual method="post"
      # form. Controller tests calling `put(:update, ...)` directly
      # bypass this entirely, so it needs its own assertion.
      assert_select("form[action=?][method='post']",
                    observation_field_slip_path(id: obs.id), count: 1)
      assert_select("form input[name='_method'][value=?]", "patch")
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
      # The rejected code should still be in the field, not lost.
      assert_select("input[name='field_code'][value=?]", "123-456")
    end

    def test_attach_blank_field_slip_code
      obs = observations(:coprinus_comatus_obs)
      login("rolf")

      put(:update, params: { id: obs.id, field_code: "" })

      assert_flash_error
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

    # This page's whole purpose is attaching a code when there isn't
    # one -- an already-attached observation must redirect away rather
    # than let a blank submit silently detach the existing slip.
    def test_edit_already_attached_redirects
      obs = observations(:minimal_unknown_obs)
      assert_not_nil(obs.field_slip, "Need obs fixture with a field slip")
      login("mary")

      get(:edit, params: { id: obs.id })

      assert_redirected_to(permanent_observation_path(obs.id))
    end

    def test_update_already_attached_does_not_detach
      obs = observations(:minimal_unknown_obs)
      slip = obs.field_slip
      assert_not_nil(slip, "Need obs fixture with a field slip")
      login("mary")

      put(:update, params: { id: obs.id, field_code: "" })

      assert_redirected_to(permanent_observation_path(obs.id))
      assert_equal(slip.id, obs.reload.field_slip&.id)
    end

    # `validate_field_slip` rejects both of these before update_field_slip
    # ever runs, so the post-validation branches only fire when the slip
    # changed underneath us between validation and application. A real
    # race can't be staged, so the status is stubbed -- the point is
    # that the branch reports rather than failing silently.
    def test_update_warns_when_field_slip_turns_invalid_after_validation
      obs = observations(:coprinus_comatus_obs)
      login("rolf")

      stub_update_field_slip(:invalid) do
        put(:update, params: { id: obs.id, field_code: "EOL-9999" })
      end

      assert_flash_error
      assert_unprocessable
      assert_nil(obs.reload.field_slip)
    end

    def test_update_warns_when_field_slip_fills_after_validation
      obs = observations(:coprinus_comatus_obs)
      login("rolf")

      stub_update_field_slip(:too_many) do
        put(:update, params: { id: obs.id, field_code: "EOL-9999" })
      end

      assert_flash_error
      assert_unprocessable
      assert_nil(obs.reload.field_slip)
    end

    private

    def stub_update_field_slip(status)
      @controller.define_singleton_method(:update_field_slip) { |*| status }
      yield
    ensure
      @controller.singleton_class.remove_method(:update_field_slip)
    end
  end
end
