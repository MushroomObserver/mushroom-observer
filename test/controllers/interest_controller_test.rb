# frozen_string_literal: true

require("test_helper")

# users interests
class InterestControllerTest < FunctionalTestCase
  # Test list feature from left-hand column.
  def test_list_interests
    login("rolf")
    Interest.create(target: observations(:minimal_unknown_obs),
                    user: rolf, state: true)
    Interest.create(target: names(:agaricus_campestris), user: rolf,
                    state: true)
    get(:list_interests)
    assert_template("list_interests")
  end

  def test_set_interest_another_user
    login("rolf")
    get(:set_interest,
        params: {
          type: "Observation",
          id: observations(:minimal_unknown_obs),
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

    # Succeed: Turn interest on in minimal_unknown.
    login("rolf")
    get(:set_interest,
        params: {
          type: "Observation", id: minimal_unknown.id, state: 1, user: rolf.id
        })
    assert_flash_success

    # Make sure rolf now has two Interests: interested in minimal_unknown,
    # plus his abiding interest in the coprinus_comatus_name_tracker.
    rolfs_interests = Interest.where(user_id: rolf.id)
    assert_equal(2, rolfs_interests.length)
    assert_equal(minimal_unknown, rolfs_interests.second.target)
    assert_equal(true, rolfs_interests.second.state)

    # Succeed: Turn same interest off.
    login("rolf")
    get(:set_interest,
        params: { type: "Observation", id: minimal_unknown.id, state: -1 })
    assert_flash_success

    # Make sure rolf now has two Interests: NOT interested in minimal_unknown.
    rolfs_interests = Interest.where(user_id: rolf.id)
    assert_equal(2, rolfs_interests.length)
    assert_equal(minimal_unknown, rolfs_interests.second.target)
    assert_equal(false, rolfs_interests.second.state)

    # Succeed: Turn another interest off from no interest.
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

    # Succeed: Delete last interest.
    login("rolf")
    get(:set_interest, params: { type: "Name", id: peltigera.id, state: 0 })
    assert_flash_success
    assert_equal(1, Interest.where(user_id: rolf.id).length)
  end

  def test_destroy_name_tracker
    login("rolf")
    n = name_trackers(:coprinus_comatus_name_tracker)
    assert(n)
    id = n.id
    get(:destroy_name_tracker, params: { id: id })
    assert_raises(ActiveRecord::RecordNotFound) do
      NameTracker.find(id)
    end
  end
end
