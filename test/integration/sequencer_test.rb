require "test_helper"

# Test to develop Sequence models, views, and controller
# TODO: delete this test once those are developed
class SequencerTest < IntegrationTestCase
  def test_sequence
    obs = observations(:coprinus_comatus_obs)

    visit("/#{obs.id}")
    click_link(:show_observation_add_sequence.l)
  end
end
