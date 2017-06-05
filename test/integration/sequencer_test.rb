require "test_helper"

# Test to develop Sequence models, views, and controller
# TODO: delete this test once those are developed
class SequencerTest < IntegrationTestCase
  def test_sequence
    obs = observations(:coprinus_comatus_obs)
    owner = obs.user

    # login
    reset_session!
    visit(root_path)
    first(:link, "Login").click
    fill_in("User name or Email address:", with: owner.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    visit("/#{obs.id}")
    click_link(:show_observation_add_sequence.l)
  end
end
