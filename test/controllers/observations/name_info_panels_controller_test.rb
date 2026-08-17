# frozen_string_literal: true

require("test_helper")

module Observations
  class NameInfoPanelsControllerTest < FunctionalTestCase
    def test_show_turbo_frame_renders_panel_content
      obs = observations(:coprinus_comatus_obs)

      login
      simulate_turbo_frame_request(obs)
      get(:show, params: { id: obs.id })

      assert_response(:success)
      assert_select("turbo-frame#name_info_frame_#{obs.id}")
      assert_select("a[href *= 'mycobank.org']")
    end

    # A direct (non-frame) visit falls back to the observation page
    # instead of rendering a bare fragment.
    def test_show_without_turbo_frame_header_redirects_to_observation
      obs = observations(:coprinus_comatus_obs)

      login
      get(:show, params: { id: obs.id })

      assert_redirected_to(permanent_observation_path(obs.id))
    end

    def test_show_requires_login
      obs = observations(:coprinus_comatus_obs)

      simulate_turbo_frame_request(obs)
      get(:show, params: { id: obs.id })

      assert_redirected_to(new_account_login_path)
    end

    def test_show_observation_not_found
      login
      simulate_turbo_frame_request_for_id(0)
      get(:show, params: { id: 0 })

      assert_redirected_to(observations_path)
    end

    private

    def simulate_turbo_frame_request(obs)
      simulate_turbo_frame_request_for_id(obs.id)
    end

    def simulate_turbo_frame_request_for_id(id)
      @request.headers["Turbo-Frame"] = "name_info_frame_#{id}"
    end
  end
end
