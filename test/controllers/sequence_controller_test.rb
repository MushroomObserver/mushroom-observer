require "test_helper"

# Controller tests for nucleotide sequences
class SequenceControllerTest < FunctionalTestCase
  def test_add_sequence_get
    # happy paths
    obs   = observations(:coprinus_comatus_obs)
    owner = obs.user

    # Prove method requires login
    requires_login(:add_sequence, id: obs.id)

    # Prove user cannot add Sequence to Observation he doesn't own
    login(users(:zero_user.login))
    get(:add_sequence, id: observations(:minimal_unknown_obs).id)
    assert_redirected_to(controller: :observer, action: :show_observation)

    # Prove Observation owner can add Sequence
    login(owner.login)
    get(:add_sequence, id: obs.id)
    assert_response(:success)
  end
end
