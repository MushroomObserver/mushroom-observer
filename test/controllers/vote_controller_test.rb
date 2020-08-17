# frozen_string_literal: true

require("test_helper")

# tests of Herbarium controller
class VoteControllerTest < FunctionalTestCase
  # ----------------------------
  #  Test voting.
  # ----------------------------

  # Now have Dick vote on Mary's name.
  # Votes: rolf=2/-3, mary=1/3, dick=-1/3
  # Rolf prefers naming 3 (vote 2 -vs- -3).
  # Mary prefers naming 9 (vote 1 -vs- 3).
  # Dick now prefers naming 9 (vote 3).
  # Summing, 3 gets 2+1/3=1, 9 gets -3+3+3/4=.75, so 3 gets it.
  def test_cast_vote_dick
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login("dick")
    post(:cast_vote, value: "3", id: nam2.id)
    assert_equal(11, dick.reload.contribution)

    # Check votes.
    assert_equal(3, nam1.reload.vote_sum)
    assert_equal(2, nam1.votes.length)
    assert_equal(3, nam2.reload.vote_sum)
    assert_equal(3, nam2.votes.length)

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # If Dick votes on the other as well, then his first vote should
    # get demoted and his preference should change.
    # Summing, 3 gets 2+1+3/4=1.5, 9 gets -3+3+2/4=.5, so 3 keeps it.
    obs.change_vote(nam1, 3, dick)
    assert_equal(12, dick.reload.contribution)
    assert_equal(3, nam1.reload.users_vote(dick).value)
    assert_equal(6, nam1.vote_sum)
    assert_equal(3, nam1.votes.length)
    assert_equal(2, nam2.reload.users_vote(dick).value)
    assert_equal(2, nam2.vote_sum)
    assert_equal(3, nam2.votes.length)
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)
  end

  # Now have Rolf change his vote on his own naming. (no change in prefs)
  # Votes: rolf=3->2/-3, mary=1/3, dick=x/x
  def test_cast_vote_rolf_change
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)

    login("rolf")
    post(:cast_vote, value: "2", id: nam1.id)
    assert_equal(10, rolf.reload.contribution)

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # Check vote.
    assert_equal(3, nam1.reload.vote_sum)
    assert_equal(2, nam1.votes.length)
  end

  # Now have Rolf increase his vote for Mary's. (changes consensus)
  # Votes: rolf=2/-3->3, mary=1/3, dick=x/x
  def test_cast_vote_rolf_second_greater
    obs  = observations(:coprinus_comatus_obs)
    nam2 = namings(:coprinus_comatus_other_naming)

    login("rolf")
    post(:cast_vote, value: "3", id: nam2.id)
    assert_equal(10, rolf.reload.contribution)

    # Make sure observation was updated right.
    assert_equal(names(:agaricus_campestris).id, obs.reload.name_id)

    # Check vote.
    assert_equal(6, nam2.reload.vote_sum)
    assert_equal(2, nam2.votes.length)
  end

  # Now have Rolf increase his vote for Mary's insufficiently. (no change)
  # Votes: rolf=2/-3->-1, mary=1/3, dick=x/x
  # Summing, 3 gets 2+1=3, 9 gets -1+3=2, so 3 keeps it.
  def test_cast_vote_rolf_second_lesser
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login("rolf")
    post(:cast_vote,
         value: "-1",
         id: nam2.id)
    assert_equal(10, rolf.reload.contribution)

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # Check vote.
    assert_equal(3, nam1.reload.vote_sum)
    assert_equal(2, nam2.reload.vote_sum)
    assert_equal(2, nam2.votes.length)
  end

  # Now, have Mary delete her vote against Rolf's naming.
  # This NO LONGER has the effect of excluding Rolf's naming
  # from the consensus calculation due to too few votes.
  # (Have Dick vote first... I forget what this was supposed to test for,
  # but it's clearly superfluous now).
  # Votes: rolf=2/-3, mary=1->x/3, dick=x/x->3
  # Summing after Dick votes,   3 gets 2+1/3=1, 9 gets -3+3+3/4=.75, 3 keeps it.
  # Summing after Mary deletes, 3 gets 2/2=1,   9 gets -3+3+3/4=.75,
  # 3 still keeps it in this voting algorithm, arg.
  def test_cast_vote_mary
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login("dick")
    obs.change_vote(nam2, 3, dick)
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)
    assert_equal(11, dick.reload.contribution)

    login("mary")
    post(:cast_vote, value: Vote.delete_vote, id: nam1.id)
    assert_equal(9, mary.reload.contribution)

    # Check votes.
    assert_equal(2, nam1.reload.vote_sum)
    assert_equal(1, nam1.votes.length)
    assert_equal(3, nam2.reload.vote_sum)
    assert_equal(3, nam2.votes.length)

    # Make sure observation is changed correctly.
    assert_equal(names(:coprinus_comatus).search_name,
                 obs.reload.name.search_name,
                 "Cache for 3: #{nam1.vote_cache}, 9: #{nam2.vote_cache}")
  end

  def test_show_votes
    # First just make sure the page displays.
    get_with_dump(:show_votes, id: namings(:coprinus_comatus_naming).id)
    assert_template(:show_votes, partial: "_show_votes")

    # Now try to make somewhat sure the content is right.
    table = namings(:coprinus_comatus_naming).calc_vote_table
    str1 = Vote.confidence(votes(:coprinus_comatus_owner_vote).value)
    str2 = Vote.confidence(votes(:coprinus_comatus_other_vote).value)
    table.each_key do |str|
      if str == str1 && str1 == str2
        assert_equal(2, table[str][:num])
      elsif str == str1
        assert_equal(1, table[str][:num])
      elsif str == str2
        assert_equal(1, table[str][:num])
      else
        assert_equal(0, table[str][:num])
      end
    end
  end
end
