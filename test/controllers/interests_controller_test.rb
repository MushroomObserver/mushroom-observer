# frozen_string_literal: true

require("test_helper")

# users interests
class InterestsControllerTest < FunctionalTestCase
  # Test list feature from left-hand column.
  def test_index
    login("rolf")
    Interest.create(target: observations(:minimal_unknown_obs),
                    user: rolf, state: true)
    Interest.create(target: names(:agaricus_campestris), user: rolf,
                    state: true)
    get(:index)
    assert_select("body.interests__index")
  end

  def test_set_interest_another_user
    login("rolf")
    get(:set_interest,
        params: {
          type: "Observation",
          id: observations(:minimal_unknown_obs).id,
          user: mary.id
        })
    assert_flash_error
  end

  def test_set_interest_no_object
    login("rolf")
    get(:set_interest, params: { type: "Observation", id: 100, state: 1 })
    assert_flash_error
  end

  def test_set_interest_bad_type
    login("rolf")
    get(:set_interest, params: { type: "Bogus", id: 1, state: 1 })
    assert_flash_error
  end

  def test_set_interest
    peltigera = names(:peltigera)
    minimal_unknown = observations(:minimal_unknown_obs)
    detailed_unknown = observations(:detailed_unknown_obs)
    coprinus_comatus_tracker = name_trackers(:coprinus_comatus_name_tracker)

    # Succeed: Turn interest on in minimal_unknown.
    login("rolf")
    get(:set_interest,
        params: {
          type: "Observation", id: minimal_unknown.id, state: 1, user: rolf.id
        })
    assert_flash_success

    # Make sure rolf now has two Interests: interested in minimal_unknown,
    # plus his abiding interest in the coprinus_comatus_tracker.
    rolfs_interests = Interest.where(user_id: rolf.id)
    assert_equal(2, rolfs_interests.length)
    assert_equal(coprinus_comatus_tracker, rolfs_interests.first.target)
    assert_equal(minimal_unknown, rolfs_interests.second.target)
    assert_equal(true, rolfs_interests.second.state)

    # Succeed: Turn same observation interest off.
    login("rolf")
    get(:set_interest,
        params: { type: "Observation", id: minimal_unknown.id, state: -1 })
    assert_flash_success

    # Make sure rolf now has two Interests: NOT interested in minimal_unknown.
    rolfs_interests = Interest.where(user_id: rolf.id)
    assert_equal(2, rolfs_interests.length)
    assert_equal(minimal_unknown, rolfs_interests.second.target)
    assert_equal(false, rolfs_interests.second.state)

    # Succeed: Turn a name interest off from no interest.
    login("rolf")
    get(:set_interest, params: { type: "Name", id: peltigera.id, state: -1 })
    assert_flash_success

    # Make sure rolf now has three Interests.
    rolfs_interests = Interest.where(user_id: rolf.id)
    assert_equal(3, rolfs_interests.length)
    assert_equal(minimal_unknown, rolfs_interests.second.target)
    assert_equal(false, rolfs_interests.second.state)
    assert_equal(peltigera, rolfs_interests.last.target)
    assert_equal(false, rolfs_interests.last.state)

    # Succeed: Delete interest in existing object that rolf hasn't expressed
    # interest in yet.
    login("rolf")
    get(:set_interest,
        params: { type: "Observation", id: detailed_unknown.id, state: 0 })
    assert_flash_success
    assert_equal(3, Interest.where(user_id: rolf.id).length)

    # Succeed: Delete first interest now.
    login("rolf")
    get(:set_interest,
        params: { type: "Observation", id: minimal_unknown.id, state: 0 })
    assert_flash_success

    # Make sure rolf now has twae Intereste: NOT interested in peltigera.
    rolfs_interests = Interest.where(user_id: rolf.id)
    assert_equal(2, rolfs_interests.length)
    assert_equal(peltigera, rolfs_interests.last.target)
    assert_equal(false, rolfs_interests.last.state)

    # Succeed: Delete last non-name-tracker interest.
    login("rolf")
    get(:set_interest, params: { type: "Name", id: peltigera.id, state: 0 })
    assert_flash_success
    assert_equal(1, Interest.where(user_id: rolf.id).length)
  end

  # `find_relevant_interests` sorts by `target_type` then `text_name`;
  # this hits the secondary tiebreak path when two interests share a
  # target_type.
  def test_index_sorts_within_target_type
    login("rolf")
    Interest.create(target: names(:agaricus_campestris),
                    user: rolf, state: true)
    Interest.create(target: names(:peltigera), user: rolf, state: true)
    get(:index)
    assert_response(:success)
  end

  # Hits `filter_interests_by_type` (only invoked when `type` param
  # present).
  # Covers `Views::Controllers::Interests::Index#render_pending_notice`
  # — the unapproved name-tracker branch (target_type=NameTracker,
  # note_template present, approved=false). No fixture matches all
  # three; build a tracker inline.
  def test_index_with_pending_name_tracker
    login("rolf")
    tracker = NameTracker.create!(
      user: rolf, name: names(:peltigera),
      note_template: "note", approved: false
    )
    Interest.create!(target: tracker, user: rolf, state: true)
    get(:index)
    assert_response(:success)
  end

  def test_index_filtered_by_type
    login("rolf")
    Interest.create(target: observations(:minimal_unknown_obs),
                    user: rolf, state: true)
    Interest.create(target: names(:agaricus_campestris),
                    user: rolf, state: true)
    get(:index, params: { type: "Observation" })
    assert_select("body.interests__index")
  end

  # set_interest's "already on" / "already off" branches.
  def test_set_interest_already_on
    login("rolf")
    obs = observations(:minimal_unknown_obs)
    Interest.create(target: obs, user: rolf, state: true)
    get(:set_interest,
        params: { type: "Observation", id: obs.id, state: 1 })
    assert_flash_success
  end

  def test_set_interest_already_off
    login("rolf")
    obs = observations(:minimal_unknown_obs)
    Interest.create(target: obs, user: rolf, state: false)
    get(:set_interest,
        params: { type: "Observation", id: obs.id, state: -1 })
    assert_flash_success
  end

  # CRUD actions — covered separately from set_interest.
  def test_create_interest
    login("rolf")
    obs = observations(:minimal_unknown_obs)
    post(:create,
         params: { type: "Observation", id: obs.id, state: 1 })
    interest = Interest.find_by(target: obs, user: rolf)
    assert(interest, "Expected a new Interest")
    assert_equal(true, interest.state)
  end

  def test_create_interest_bad_target
    login("rolf")
    post(:create,
         params: { type: "Observation", id: 99_999, state: 1 })
    assert_flash_error
  end

  def test_update_interest
    login("rolf")
    obs = observations(:minimal_unknown_obs)
    Interest.create(target: obs, user: rolf, state: true)
    patch(:update,
          params: { type: "Observation", id: obs.id, state: -1 })
    assert_equal(false, Interest.find_by(target: obs, user: rolf).state)
  end

  def test_update_creates_interest_when_missing
    login("rolf")
    obs = observations(:detailed_unknown_obs)
    patch(:update,
          params: { type: "Observation", id: obs.id, state: 1 })
    interest = Interest.find_by(target: obs, user: rolf)
    assert(interest, "Update should create the interest if missing")
    assert_equal(true, interest.state)
  end

  def test_update_no_op_when_state_zero_and_no_interest
    login("rolf")
    obs = observations(:detailed_unknown_obs)
    assert_no_difference("Interest.count") do
      patch(:update,
            params: { type: "Observation", id: obs.id, state: 0 })
    end
  end

  def test_destroy_interest
    login("rolf")
    obs = observations(:minimal_unknown_obs)
    Interest.create(target: obs, user: rolf, state: true)
    delete(:destroy,
           params: { type: "Observation", id: obs.id })
    assert_nil(Interest.find_by(target: obs, user: rolf))
  end

  def test_destroy_already_deleted_interest
    login("rolf")
    obs = observations(:detailed_unknown_obs)
    delete(:destroy,
           params: { type: "Observation", id: obs.id })
    assert_flash_success
  end

  def test_destroy_name_tracker_target_destroys_tracker
    login("rolf")
    tracker = name_trackers(:coprinus_comatus_name_tracker)
    delete(:destroy,
           params: { type: "NameTracker", id: tracker.id })
    assert_nil(NameTracker.find_by(id: tracker.id))
  end

  def test_delete_name_tracker_interest
    coprinus_comatus_tracker = name_trackers(:coprinus_comatus_name_tracker)

    # Now, delete the interest in the name_tracker, and be sure also deleted
    login("rolf")
    get(:set_interest, params: { type: "NameTracker",
                                 id: coprinus_comatus_tracker.id,
                                 state: 0 })
    assert_flash_success
    assert_equal(0, Interest.where(user_id: rolf.id).length)
    assert_equal(0, NameTracker.where(user_id: rolf.id).length)
  end
end
