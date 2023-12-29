# frozen_string_literal: true

require("test_helper")
# test Observation model
class ObservationTest < UnitTestCase
  def create_new_objects
    @cc_obs = Observation.new
    @cc_obs.user = mary
    @cc_obs.when = Time.zone.now
    @cc_obs.where = "Glendale, California"
    @cc_obs.notes = "New"
    @cc_obs.name = names(:fungi)

    @cc_nam = Naming.new
    @cc_nam.user = mary
    @cc_nam.name = names(:fungi)
    @cc_nam.observation = @cc_obs
  end

  ##############################################################################

  # Add an observation to the database
  def test_create
    create_new_objects
    assert_kind_of(Observation, observations(:minimal_unknown_obs))
    assert_kind_of(Observation, @cc_obs)
    assert_kind_of(Naming, namings(:minimal_unknown_naming))
    assert_kind_of(Naming, @cc_nam)
    assert_save(@cc_obs)
    assert_save(@cc_nam)
  end

  def test_update
    create_new_objects
    assert_save(@cc_nam)
    assert_equal(names(:fungi), @cc_nam.name)
    @cc_nam.name = names(:coprinus_comatus)
    assert_save(@cc_nam)
    @cc_nam.reload
    assert_equal(names(:coprinus_comatus).search_name, @cc_nam.text_name)
  end

  # Test setting a name using a string
  def test_validate
    create_new_objects
    @cc_obs.user = nil
    @cc_obs.when = nil   # no longer an error, defaults to today
    @cc_obs.where = nil  # no longer an error, defaults to Location.unknown
    assert_not(@cc_obs.save)
    assert_equal(1, @cc_obs.errors.count)
    assert_equal(:validate_observation_user_missing.t,
                 @cc_obs.errors[:user].first)
  end

  def test_destroy
    create_new_objects
    User.current = rolf
    assert_save(@cc_obs)
    assert_save(@cc_nam)
    @cc_obs.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Observation.find(@cc_obs.id) }
    assert_raise(ActiveRecord::RecordNotFound) { Naming.find(@cc_nam.id) }
  end

  def test_remove_image_twice
    observations(:minimal_unknown_obs).images = [
      images(:commercial_inquiry_image),
      images(:disconnected_coprinus_comatus_image),
      images(:connected_coprinus_comatus_image)
    ]
    observations(:minimal_unknown_obs).
      thumb_image = images(:commercial_inquiry_image)
    observations(:minimal_unknown_obs).
      remove_image(images(:commercial_inquiry_image))
    assert_equal(observations(:minimal_unknown_obs).thumb_image,
                 images(:disconnected_coprinus_comatus_image))
    observations(:minimal_unknown_obs).
      remove_image(images(:disconnected_coprinus_comatus_image))
    assert_equal(observations(:minimal_unknown_obs).thumb_image,
                 images(:connected_coprinus_comatus_image))
  end

  def test_name_been_proposed
    assert(observations(:coprinus_comatus_obs).
      name_been_proposed?(names(:coprinus_comatus)))
    assert(observations(:coprinus_comatus_obs).
      name_been_proposed?(names(:agaricus_campestris)))
    assert_not(observations(:coprinus_comatus_obs).
      name_been_proposed?(names(:conocybe_filaris)))
  end

  # --------------------------------------
  #  Test owner id, favorites, consensus
  # --------------------------------------

  def obs_consensus(fixture_name)
    Observation::NamingConsensus.new(observations(fixture_name))
  end

  # Test Observer's Prefered ID
  def test_observer_preferred_id
    # obs = observations(:owner_only_favorite_ne_consensus)
    # consensus = Observation::NamingConsensus.new(obs)
    consensus = obs_consensus(:owner_only_favorite_ne_consensus)
    assert_equal(names(:tremella_mesenterica), consensus.owner_preference)

    consensus = obs_consensus(:owner_only_favorite_eq_consensus)
    assert_equal(names(:boletus_edulis), consensus.owner_preference)

    # previously untested bug: this obs does not have a naming.
    obs = observations(:owner_only_favorite_eq_fungi)
    # fix: give it a "fungi" naming from another fixture.
    nam = namings(:detailed_unknown_naming)
    nam.update(observation_id: obs.id)
    consensus = Observation::NamingConsensus.new(obs.reload)
    assert_equal(names(:fungi), consensus.owner_preference)

    # obs Site ID is Fungi, but owner did not propose a Name
    consensus = obs_consensus(:minimal_unknown_obs)
    assert_not(consensus.owner_preference)

    consensus = obs_consensus(:owner_multiple_favorites)
    assert_not(consensus.owner_preference)

    consensus = obs_consensus(:owner_uncertain_favorite)
    assert_not(consensus.owner_preference)
  end

  def test_change_vote_weakened_favorite
    vote = votes(:owner_only_favorite_ne_consensus)
    vote.observation.change_vote(vote.naming, Vote.min_pos_vote, vote.user)
    vote.reload

    assert_equal(true, vote.favorite,
                 "Weakened favorite should remain favorite")
  end

  # Prove that when user's favorite vote is deleted,
  # user's 2nd positive vote becomes user's favorite
  def test_change_vote_2nd_positive_choice_becomes_favorite
    naming_top = namings(:unequal_positive_namings_top_naming)
    obs = naming_top.observation
    user = naming_top.user
    old_2nd_choice = votes(:unequal_positive_namings_obs_2nd_vote)

    obs.change_vote(naming_top, Vote.delete_vote, user)
    old_2nd_choice.reload

    assert_equal(true, old_2nd_choice.favorite)
  end

  # Prove that when all an Observation's Namings are deprecated,
  # calc_consensus returns the synonym of the consensus with the highest vote.
  def test_calc_consensus_all_namings_deprecated
    obs = observations(:all_namings_deprecated_obs)
    winning_naming = namings(:all_namings_deprecated_winning_naming)
    assert_equal(winning_naming, obs.consensus_naming)
  end

  # --------------------------------------

  def test_herbarium_records
    assert_not(observations(:strobilurus_diminutivus_obs).specimen)
    assert_empty(observations(:strobilurus_diminutivus_obs).herbarium_records)
    assert(observations(:detailed_unknown_obs).specimen)
    assert_not(observations(:detailed_unknown_obs).herbarium_records.empty?)
  end

  def test_minimal_map_observation
    obs = observations(:minimal_unknown_obs)

    min_map = Mappable::MinimalObservation.new(obs.id, obs.lat, obs.long,
                                               obs.location.id)
    assert_objs_equal(locations(:burbank), min_map.location)
    assert_equal(locations(:burbank).id, min_map.location_id)

    min_map = Mappable::MinimalObservation.new(obs.id, obs.lat, obs.long,
                                               obs.location)
    assert_objs_equal(locations(:burbank), min_map.location)
    assert_equal(locations(:burbank).id, min_map.location_id)

    assert(min_map.observation?)
    assert_not(min_map.location?)
    assert_not(min_map.lat_long_dubious?)

    min_map.location = locations(:albion)
    assert_objs_equal(locations(:albion), min_map.location)
    assert_equal(locations(:albion).id, min_map.location_id)

    min_map.location = nil
    assert_nil(min_map.location)
    assert_nil(min_map.location_id)
  end

  # Prove that unique_format_name returns blank string on error
  def test_unique_format_name_rescue
    obs = Observation.first
    obs.name.display_name = nil # mess up display_name to cause error
    assert_equal("", obs.unique_format_name)
  end

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------
  def test_email_notification_1
    NameTracker.all.map(&:destroy)
    QueuedEmail.queue = true

    obs = observations(:coprinus_comatus_obs)

    # Make sure Rolf has requested emails.
    rolf.email_comments_owner = true
    rolf.email_comments_response = true
    rolf.email_observations_naming = true
    rolf.email_observations_consensus = true
    assert_save(rolf)

    # Make sure observation name starts as Coprinus comatus.
    assert_equal(names(:coprinus_comatus), obs.name)

    # Observation owner is not notified if comment added by themselves.
    # (Rolf owns coprinus_comatus_obs, one naming, two votes, conf. around 1.5.)
    # (But Mary will get a comment-response email because she has a naming.)
    User.current = rolf
    Comment.create(
      summary: "This is Rolf...",
      target: obs
    )
    assert_equal(1, QueuedEmail.count)

    # Observation owner is not notified if naming added by themselves.
    User.current = rolf
    new_naming = Naming.create(
      observation: obs,
      name: names(:agaricus_campestris),
      vote_cache: 0
    )
    assert_equal(1, QueuedEmail.count)
    assert_equal(names(:coprinus_comatus), obs.reload.name)

    # Observation owner is not notified if consensus changed by themselves.
    User.current = rolf
    obs.change_vote(new_naming, 3)
    assert_equal(names(:agaricus_campestris), obs.reload.name)
    assert_equal(1, QueuedEmail.count)

    # Make Rolf opt out of all emails.
    rolf.email_comments_owner = false
    rolf.email_comments_response = false
    rolf.email_observations_naming = false
    rolf.email_observations_consensus = false
    assert_save(rolf)

    # Rolf should not be notified of anything here, either...
    # But Mary still will get something for having the naming.
    User.current = dick
    Comment.create(
      summary: "This is Dick...",
      target: obs.reload
    )
    assert_equal(2, QueuedEmail.count)

    User.current = dick
    new_naming = Naming.create(
      observation: obs,
      name: names(:peltigera),
      vote_cache: 0
    )
    assert_equal(2, QueuedEmail.count)
    assert_equal(names(:agaricus_campestris), obs.reload.name)

    # Make sure this changes consensus...
    dick.contribution = 2_000_000_000
    assert_save(dick)

    User.current = dick
    obs.change_vote(new_naming, 3)
    assert_equal(names(:peltigera), obs.reload.name)
    assert_equal(2, QueuedEmail.count)
    QueuedEmail.queue = false
  end

  def test_email_notification_2
    NameTracker.all.map(&:destroy)
    QueuedEmail.queue = true

    obs = observations(:coprinus_comatus_obs)

    # Make sure Rolf has requested no emails (will turn on one at a time to be
    # sure the right pref affects the right notification).
    rolf.email_comments_owner = false
    rolf.email_comments_response = false
    rolf.email_observations_naming = false
    rolf.email_observations_consensus = false
    assert_save(rolf)

    # Observation owner is notified if comment added by someone else.
    # (Rolf owns observations(:coprinus_comatus_obs),
    # one naming, two votes, conf. around 1.5.)
    rolf.email_comments_owner = true
    assert_save(rolf)
    User.current = mary
    new_comment = Comment.create(
      summary: "This is Mary...",
      target: obs
    )
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
                 flavor: "QueuedEmail::CommentAdd",
                 from: mary,
                 to: rolf,
                 comment: new_comment.id)

    # Observation owner is notified if naming added by someone else.
    rolf.email_comments_owner = false
    rolf.email_observations_naming = true
    assert_save(rolf)
    User.current = mary
    new_naming = Naming.create(
      observation: obs.reload,
      name: names(:agaricus_campestris),
      vote_cache: 0
    )
    assert_equal(2, QueuedEmail.count)
    assert_email(1,
                 flavor: "QueuedEmail::NameProposal",
                 from: mary,
                 to: rolf,
                 observation: obs.id,
                 naming: new_naming.id)

    # Observation owner is notified if consensus changed by someone else.
    rolf.email_observations_naming = false
    rolf.email_observations_consensus = true
    assert_save(rolf)
    # (Actually, Mary already gave this her highest possible vote,
    # so think of this as Mary changing Rolf's vote. :)
    User.current = mary
    obs.change_vote(namings(:coprinus_comatus_other_naming), 3, rolf)
    assert_equal(3,
                 votes(:coprinus_comatus_other_naming_rolf_vote).reload.value)
    assert_equal(3, QueuedEmail.count)
    assert_email(2,
                 flavor: "QueuedEmail::ConsensusChange",
                 from: mary,
                 to: rolf,
                 observation: obs.id,
                 old_name: names(:coprinus_comatus).id,
                 new_name: names(:agaricus_campestris).id)

    # Make sure Mary gets notified if Rolf responds to her comment.
    mary.email_comments_response = true
    assert_save(mary)
    User.current = rolf
    new_comment = Comment.create(
      summary: "This is Rolf...",
      target: observations(:coprinus_comatus_obs)
    )
    assert_equal(4, QueuedEmail.count)
    assert_email(3,
                 flavor: "QueuedEmail::CommentAdd",
                 from: rolf,
                 to: mary,
                 comment: new_comment.id)
    QueuedEmail.queue = false
  end

  def test_email_notification_3
    NameTracker.all.map(&:destroy)
    QueuedEmail.queue = true

    obs = observations(:coprinus_comatus_obs)

    # Make sure Rolf has requested emails.
    rolf.email_comments_owner = true
    rolf.email_comments_response = true
    rolf.email_observations_naming = true
    rolf.email_observations_consensus = true
    assert_save(rolf)

    # Make sure Dick has requested no emails.
    dick.email_comments_owner = false
    dick.email_comments_response = false
    dick.email_observations_naming = false
    dick.email_observations_consensus = false
    assert_save(dick)

    # Make Rolf ignore his own observation (will override prefs).
    Interest.create(
      target: obs,
      user: rolf,
      state: false
    )

    # But make Dick watch it (will override prefs).
    Interest.create(
      target: observations(:coprinus_comatus_obs),
      user: dick,
      state: true
    )

    # Watcher is notified if comment added.
    # (Rolf owns observations(:coprinus_comatus_obs),
    # one naming, two votes, conf. around 1.5.)
    User.current = mary
    new_comment = Comment.create(
      summary: "This is Mary...",
      target: observations(:coprinus_comatus_obs)
    )
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
                 flavor: "QueuedEmail::CommentAdd",
                 from: mary,
                 to: dick,
                 comment: new_comment.id)

    # Watcher is notified if naming added.
    User.current = mary
    new_naming = Naming.create(
      observation: observations(:coprinus_comatus_obs),
      name: names(:agaricus_campestris),
      vote_cache: 0
    )
    assert_equal(2, QueuedEmail.count)
    assert_email(1,
                 flavor: "QueuedEmail::NameProposal",
                 from: mary,
                 to: dick,
                 observation: observations(:coprinus_comatus_obs).id,
                 naming: new_naming.id)

    # Watcher is notified if consensus changed.
    # (Actually, Mary already gave this her highest possible vote,
    # so think of this as Mary changing Rolf's vote. :)
    User.current = mary
    obs.change_vote(namings(:coprinus_comatus_other_naming), 3, rolf)
    assert_equal(3,
                 votes(:coprinus_comatus_other_naming_rolf_vote).reload.value)
    assert_save(votes(:coprinus_comatus_other_naming_rolf_vote))
    assert_equal(3, QueuedEmail.count)
    assert_email(2,
                 flavor: "QueuedEmail::ConsensusChange",
                 from: mary,
                 to: dick,
                 observation: observations(:coprinus_comatus_obs).id,
                 old_name: names(:coprinus_comatus).id,
                 new_name: names(:agaricus_campestris).id)

    # Now have Rolf make a bunch of changes...
    User.current = rolf

    # Watcher is also notified of changes in the observation.
    obs.notes = "I have new information on this observation."
    obs.save
    assert_equal(4, QueuedEmail.count)

    # Make sure subsequent changes update existing email.
    obs.where = "Somewhere else"
    obs.save
    assert_equal(4, QueuedEmail.count)

    # Same deal with adding and removing images.
    obs.add_image(images(:disconnected_coprinus_comatus_image))
    assert_equal(4, QueuedEmail.count)
    obs.remove_image(images(:disconnected_coprinus_comatus_image))
    assert_equal(4, QueuedEmail.count)

    # All the above modify this email:
    assert_email(3,
                 flavor: "QueuedEmail::ObservationChange",
                 from: rolf,
                 to: dick,
                 observation: observations(:coprinus_comatus_obs).id,
                 note: "notes,location,added_image,removed_image")
    QueuedEmail.queue = false
  end

  def test_email_notification_4
    NameTracker.all.map(&:destroy)
    QueuedEmail.queue = true

    obs = observations(:coprinus_comatus_obs)
    marys_interest = Interest.create(
      target: observations(:coprinus_comatus_obs),
      user: mary,
      state: false
    )
    dicks_interest = Interest.create(
      target: observations(:coprinus_comatus_obs),
      user: dick,
      state: false
    )
    katrinas_interest = Interest.create(
      target: observations(:coprinus_comatus_obs),
      user: katrina,
      state: false
    )

    # Make change to observation.
    marys_interest.state = true
    assert_save(marys_interest)

    User.current = rolf
    observations(:coprinus_comatus_obs).
      notes = "I have new information on this observation."
    observations(:coprinus_comatus_obs).save
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
                 flavor: "QueuedEmail::ObservationChange",
                 from: rolf,
                 to: mary,
                 observation: observations(:coprinus_comatus_obs).id,
                 note: "notes")

    # Add image to observation.
    marys_interest.state = false
    assert_save(marys_interest)
    dicks_interest.state = true
    assert_save(dicks_interest)
    User.current = rolf
    obs.reload.add_image(images(:disconnected_coprinus_comatus_image))

    assert_equal(2, QueuedEmail.count)
    assert_email(1,
                 flavor: "QueuedEmail::ObservationChange",
                 from: rolf,
                 to: dick,
                 observation: observations(:coprinus_comatus_obs).id,
                 note: "added_image")

    # Destroy observation.
    dicks_interest.state = false
    assert_save(dicks_interest)
    katrinas_interest.state = true
    assert_save(katrinas_interest)

    User.current = rolf
    assert_equal(2, QueuedEmail.count)
    obs.reload.destroy
    assert_equal(3, QueuedEmail.count)
    assert_email(2,
                 flavor: "QueuedEmail::ObservationChange",
                 from: rolf,
                 to: katrina,
                 observation: 0,
                 note: "**__Coprinus comatus__** (O.F. Müll.) Pers. " \
                       "(#{observations(:coprinus_comatus_obs).id})")
    QueuedEmail.queue = false
  end

  def test_vote_favorite
    @fungi = names(:fungi)
    @name1 = names(:agaricus_campestris)
    @name2 = names(:coprinus_comatus)
    @name3 = names(:conocybe_filaris)

    User.current = rolf
    obs = Observation.create!(
      when: Time.zone.today,
      where: "anywhere",
      name_id: @fungi.id
    )

    User.current = rolf
    namg1 = Naming.create!(
      observation_id: obs.id,
      name_id: @name1.id
    )

    User.current = mary
    namg2 = Naming.create!(
      observation_id: obs.id,
      name_id: @name2.id
    )

    User.current = dick
    namg3 = Naming.create!(
      observation_id: obs.id,
      name_id: @name3.id
    )

    namings = [namg1, namg2, namg3]

    # Okay, nothing has votes yet.
    obs.reload
    assert_equal(@fungi, obs.name)
    assert_nil(obs.consensus_naming)
    assert_not(obs.owner_voted?(namg1))
    assert_not(obs.user_voted?(namg1, rolf))
    assert_not(obs.user_voted?(namg1, mary))
    assert_not(obs.user_voted?(namg1, dick))
    assert_nil(obs.owners_vote(namg1))
    assert_nil(obs.users_vote(namg1, rolf))
    assert_nil(obs.users_vote(namg1, mary))
    assert_nil(obs.users_vote(namg1, dick))
    assert_not(obs.users_favorite?(namg1, rolf))
    assert_not(obs.users_favorite?(namg1, mary))
    assert_not(obs.users_favorite?(namg1, dick))

    # They're all the same, none with votes yet, so first apparently wins.
    obs.calc_consensus
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, obs.consensus_naming)

    # Play with Rolf's vote for his naming (first naming).
    obs.change_vote(namg1, 2, rolf)
    namg1.reload
    assert(obs.owner_voted?(namg1))
    assert(obs.user_voted?(namg1, rolf))
    assert(vote = obs.owners_vote(namg1))
    assert_equal(vote, obs.users_vote(namg1, rolf))
    assert_equal(vote, namg1.users_vote(rolf))
    assert(obs.owners_favorite?(namg1))
    assert(obs.users_favorite?(namg1, rolf))
    assert(namg1.users_favorite?(rolf))
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, obs.consensus_naming)

    obs.change_vote(namg1, 0.01, rolf)
    namg1.reload
    assert(obs.owners_favorite?(namg1))
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, obs.consensus_naming)

    obs.change_vote(namg1, -0.01, rolf)
    namg1.reload
    assert_not(obs.owners_favorite?(namg1))
    assert_not(namg1.users_favorite?(rolf))
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, obs.consensus_naming)

    # Play with Rolf's vote for other namings.
    # Make votes namg1: -0.01, namg2: 1, namg3: 0
    obs.change_vote(namg2, 1, rolf)
    namings.each(&:reload)
    namg2.reload
    assert_not(obs.owners_favorite?(namg1))
    assert(obs.owners_favorite?(namg2))
    assert_not(obs.owners_favorite?(namg3))
    assert_names_equal(@name2, obs.name)
    assert_equal(namg2, obs.consensus_naming)

    # Make votes namg1: -0.01, namg2: 1, namg3: 2
    obs.change_vote(namg3, 2, rolf)
    namings.each(&:reload)
    assert_not(obs.owners_favorite?(namg1))
    assert_not(obs.owners_favorite?(namg2))
    assert(obs.owners_favorite?(namg3))
    assert_names_equal(@name3, obs.name)
    assert_equal(namg3, obs.consensus_naming)

    # Make votes namg1: 3, namg2: 1, namg3: 2
    obs.change_vote(namg1, 3, rolf)
    namings.each(&:reload)
    assert(obs.owners_favorite?(namg1))
    assert_not(obs.owners_favorite?(namg2))
    assert_not(obs.owners_favorite?(namg3))
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, obs.consensus_naming)

    # Make votes namg1: 1, namg2: 1, namg3: 2
    obs.change_vote(namg1, 1, rolf)
    namings.each(&:reload)
    assert_not(obs.owners_favorite?(namg1))
    assert_not(obs.owners_favorite?(namg2))
    assert(obs.owners_favorite?(namg3))
    assert_names_equal(@name3, obs.name)
    assert_equal(namg3, obs.consensus_naming)

    # Play with Mary's vote. Make votes:
    # namg1 Agaricus campestris L.: rolf=1.0, mary=1.0
    # namg2 Coprinus comatus (O.F. Müll.) Pers.: rolf=1.0, mary=2.0(*)
    # namg3 Conocybe filaris: rolf=2.0(*), mary=-1.0
    obs.change_vote(namg1, 1, mary)
    obs.change_vote(namg2, 2, mary)
    obs.change_vote(namg3, -1, mary)
    namings.each(&:reload)
    assert_not(namg1.users_favorite?(mary))
    assert(namg2.users_favorite?(mary))
    assert_not(namg3.users_favorite?(mary))
    assert_names_equal(@name2, obs.name)
    assert_equal(namg2, obs.consensus_naming)

    # namg1 Agaricus campestris L.: rolf=1.0, mary=1.0(*)
    # namg2 Coprinus comatus (O.F. Müll.) Pers.: rolf=1.0, mary=0.01
    # namg3 Conocybe filaris: rolf=2.0(*), mary=-1.0
    obs.change_vote(namg2, 0.01, mary)
    namings.each(&:reload)
    assert(namg1.users_favorite?(mary))
    assert_not(namg2.users_favorite?(mary))
    assert_not(namg3.users_favorite?(mary))
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, obs.consensus_naming)

    obs.change_vote(namg1, -0.01, mary)
    namings.each(&:reload)
    assert_not(namg1.users_favorite?(mary))
    assert(namg2.users_favorite?(mary))
    assert_not(namg3.users_favorite?(mary))
    assert_not(namg1.users_favorite?(rolf))
    assert_not(namg2.users_favorite?(rolf))
    assert(namg3.users_favorite?(rolf))
    assert_not(namg1.users_favorite?(dick))
    assert_not(namg2.users_favorite?(dick))
    assert_not(namg3.users_favorite?(dick))
    assert_names_equal(@name3, obs.name)
    assert_equal(namg3, obs.consensus_naming)
  end

  def test_project_ownership
    # NOT owned by Bolete project, but owned by Mary
    obs = observations(:minimal_unknown_obs)
    assert_false(obs.can_edit?(rolf))
    assert_true(obs.can_edit?(mary))
    assert_false(obs.can_edit?(dick))

    # IS owned by Bolete project, AND owned by Mary
    # (Dick is member of Bolete project)
    obs = observations(:detailed_unknown_obs)
    assert_false(obs.can_edit?(rolf))
    assert_true(obs.can_edit?(mary))
    assert_true(obs.can_edit?(dick))
  end

  def test_open_membership_project_ownership
    # Part of Burbank project, but owned by Roy
    obs = observations(:owner_accepts_general_questions)
    assert_false(obs.can_edit?(rolf))
    assert_true(obs.can_edit?(roy)) # Owner & project admin
    assert_false(obs.can_edit?(katrina)) # Project member
  end

  def test_imageless
    # has image
    assert_true(observations(:coprinus_comatus_obs).has_backup_data?)

    # has species list
    assert_true(observations(:minimal_unknown_obs).has_backup_data?)

    # has specimen
    assert_true(observations(:amateur_obs).has_backup_data?)

    # not enough notes
    assert_false(observations(:agaricus_campestrus_obs).has_backup_data?)
  end

  def test_dump_votes
    obs = observations(:coprinus_comatus_obs)
    # Add a Naming with no votes to completely test dump_votes.
    no_votes_naming = Naming.new(
      observation_id: obs.id,
      name_id: names(:fungi).id,
      user_id: users(:rolf).id
    )
    no_votes_naming.save!
    votes = "#{obs.namings.first.id} Agaricus campestris L.: " \
              "mary=3.0(*), rolf=-3.0\n" \
            "#{obs.namings.second.id} Coprinus comatus (O.F. Müll.) Pers.: " \
              "mary=1.0(*), rolf=2.0(*)\n" \
            "#{no_votes_naming.id} Fungi: no votes"

    assert_equal(votes, obs.dump_votes)
  end

  # --------------------------------------------------
  #  Notes: Test methods related to serialized notes
  # --------------------------------------------------

  def test_notes_export_format
    assert_equal(
      "",
      observations(:minimal_unknown_obs).notes_export_formatted
    )

    assert_equal(
      "Found in a strange place... & with śtrangè characters™",
      observations(:detailed_unknown_obs).notes_export_formatted
    )
    assert_equal(
      "substrate: soil",
      observations(:substrate_notes_obs).notes_export_formatted
    )
    assert_equal(
      "substrate: soil\nOther: slimy",
      observations(:substrate_and_other_notes_obs).notes_export_formatted
    )
  end

  def test_notes_show_format
    assert_equal(
      "", observations(:minimal_unknown_obs).notes_show_formatted
    )
    assert_equal(
      "Found in a strange place... & with śtrangè characters™",
      observations(:detailed_unknown_obs).notes_show_formatted
    )
    assert_equal(
      "+substrate+: soil",
      observations(:substrate_notes_obs).notes_show_formatted
    )
    assert_equal(
      "+substrate+: soil\n+Other+: slimy",
      observations(:substrate_and_other_notes_obs).notes_show_formatted
    )
  end

  # Prove that notes parts for Views are assembled in this order
  #   - notes_template parts, in order listed in notes_template
  #   - orphaned parts, in order that they appear in Observation
  #   - Other
  def test_form_notes_parts
    # no template and no notes
    obs   = observations(:minimal_unknown_obs)
    parts = ["Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # no template and Other notes
    obs   = observations(:detailed_unknown_obs)
    parts = ["Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # no template and orphaned notes
    obs   = observations(:substrate_notes_obs)
    parts = %w[substrate Other]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # no template, and orphaned notes and Other notes
    obs   = observations(:substrate_and_other_notes_obs)
    parts = %w[substrate Other]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # template and no notes
    obs   = observations(:templater_noteless_obs)
    parts = ["Cap", "Nearby trees", "odor", "Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # template and other notes
    obs   = observations(:templater_other_notes_obs)
    parts = ["Cap", "Nearby trees", "odor", "Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # template and orphaned notes
    obs   = observations(:templater_orphaned_notes_obs)
    parts = ["Cap", "Nearby trees", "odor", "orphaned_caption", "Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # template and notes for a template part
    obs   = observations(:template_only_obs)
    parts = ["Cap", "Nearby trees", "odor", "Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # template and notes for a template part and Other notes
    obs   = observations(:template_and_other_notes_obs)
    parts = ["Cap", "Nearby trees", "odor", "Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # template and notes for a template part and orphaned part
    obs   = observations(:template_and_orphaned_notes_obs)
    parts = ["Cap", "Nearby trees", "odor", "orphaned_caption", "Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # template and notes for a template part, orphaned part, Other,
    # with order scrambled in the Observation
    obs   = observations(:template_and_orphaned_notes_scrambled_obs)
    parts = ["Cap", "Nearby trees", "odor", "orphaned_caption_1",
             "orphaned_caption_2", "Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))
  end

  # Prove that part value is returned for the given key,
  # including any required normalization of the key
  def test_notes_parts_values
    obs = observations(:template_and_orphaned_notes_scrambled_obs)
    assert_equal("red", obs.notes_part_value("Cap"))
    assert_equal("pine", obs.notes_part_value("Nearby trees"))
  end

  def test_make_sure_no_observations_are_misspelled
    good = names(:peltigera)
    bad  = names(:petigera)
    misspelled_obs = Observation.where(name: good)
    misspelled_obs.each do |obs|
      obs.update_columns(name_id: bad.id)
      assert_operator(obs.updated_at, :<, 1.minute.ago)
    end
    Observation.make_sure_no_observations_are_misspelled
    misspelled_obs.each do |obs|
      assert_names_equal(good, obs.reload.name)
      assert_operator(obs.updated_at, :<, 1.minute.ago)
    end
  end

  def test_gps_hidden
    obs = observations(:unknown_with_lat_long)
    assert_equal(34.1622, obs.lat)
    assert_equal(-118.3521, obs.long)
    assert_equal(34.1622, obs.public_lat)
    assert_equal(-118.3521, obs.public_long)

    obs.update_attribute(:gps_hidden, true)
    assert_nil(obs.public_lat)
    assert_nil(obs.public_long)
    User.current = mary
    assert_equal(34.1622, obs.public_lat)
    assert_equal(-118.3521, obs.public_long)
  end

  def test_place_name_and_coordinates_with_values
    obs = observations(:amateur_obs)
    assert_equal(obs.place_name_and_coordinates,
                 "Pasadena, California, USA (34.1622°N 118.3521°W)")
  end

  def test_place_name_and_coordinates_without_values
    obs = observations(:unknown_with_no_naming)
    assert_equal(obs.place_name_and_coordinates, "Who knows where")
  end

  def test_check_requirements_no_user
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id)
    end
    assert_match(:validate_observation_user_missing.t, exception.message)
  end

  def test_check_requirements_future_date
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, when: Time.zone.today + 2.days)
    end
    assert_match(:validate_future_time.t, exception.message)
  end

  def test_check_requirements_future_time
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      # Note that 'when' gets automagically converted to Date
      Observation.create!(name_id: fungi.id, when: 2.days.from_now)
    end
    assert_match(:validate_future_time.t, exception.message)
  end

  def test_check_requirements_invalid_year
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, when: Date.new(1499, 1, 1))
    end
    assert_match(:validate_invalid_year.t, exception.message)
  end

  def test_check_requirements_where_too_long
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, where: "X" * 1025)
    end
    assert_match(:validate_observation_where_too_long.t, exception.message)
  end

  def test_check_requirements_where_no_latitude
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, long: 90.0)
    end
    assert_match(:runtime_lat_long_error.t, exception.message)
  end

  def test_check_requirements_where_no_longitude
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, lat: 90.0)
    end
    assert_match(:runtime_lat_long_error.t, exception.message)
  end

  def test_check_requirements_where_bad_altitude
    User.current = mary
    fungi = names(:fungi)
    # Currently all strings are parsable as altitude
    assert_nothing_raised do
      Observation.create!(name_id: fungi.id, alt: "This should be bad")
    end
  end

  def test_check_requirements_with_valid_when_str
    User.current = mary
    fungi = names(:fungi)
    assert_nothing_raised do
      Observation.create!(name_id: fungi.id, when_str: "2020-07-05")
    end
  end

  def test_check_requirements_with_invalid_when_str_date
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, when_str: "0000-00-00")
    end
    assert_match(:runtime_date_invalid.t, exception.message)
  end

  def test_check_requirements_with_invalid_when_str
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, when_str: "This is not a date")
    end
    assert_match(:runtime_date_should_be_yyyymmdd.t, exception.message)
  end

  def test_update_view_stats
    obs = observations(:minimal_unknown_obs)
    assert_nil(obs.last_view)
    assert_equal(0, obs.num_views)
    assert_nil(obs.old_last_view)
    assert_equal(0, obs.old_num_views)
    assert_nil(obs.last_viewed_by(dick))
    assert_nil(obs.old_last_viewed_by(dick))

    User.current = dick
    obs.update_view_stats
    assert_operator(obs.last_view, :>=, 2.seconds.ago)
    assert_equal(1, obs.num_views)
    assert_nil(obs.old_last_view)
    assert_equal(0, obs.old_num_views)
    assert_operator(obs.last_viewed_by(dick), :>=, 2.seconds.ago)
    assert_nil(obs.old_last_viewed_by(dick))

    time = 1.day.ago
    obs.update!(last_view: time)
    obs.observation_views.where(user: dick).first.update!(last_view: time)
    # Make sure this is a totally fresh instance.
    obs = Observation.find(obs.id)

    obs.update_view_stats
    assert_operator(obs.last_view, :>=, 2.seconds.ago)
    assert_equal(2, obs.num_views)
    assert_operator(obs.old_last_view, :>=, time - 2.seconds)
    assert_operator(obs.old_last_view, :<=, time + 2.seconds)
    assert_equal(1, obs.old_num_views)
    assert_operator(obs.last_viewed_by(dick), :>=, 2.seconds.ago)
    assert_operator(obs.old_last_viewed_by(dick), :>=, time - 2.seconds)
    assert_operator(obs.old_last_viewed_by(dick), :<=, time + 2.seconds)
  end

  def test_destroy_orphans_log
    obs = observations(:detailed_unknown_obs)
    log = obs.rss_log
    assert_not_nil(log)
    obs.destroy!
    assert_nil(log.reload.target_id)
  end

  # ----------------------------------------------------------
  #  Scopes: Tests of scopes not completely covered elsewhere
  # ----------------------------------------------------------

  def start_of_time
    Date.jd(0).strftime("%Y-%m-%d")
  end

  def a_century_from_now
    (Time.zone.today + 100.years).strftime("%Y-%m,-%d")
  end

  def two_centuries_from_now
    (Time.zone.today + 200.years).strftime("%Y-%m-%d")
  end

  def test_scope_found_on
    obs = observations(:minimal_unknown_obs)
    assert_includes(Observation.found_on(obs.when), obs)
    assert_empty(Observation.found_on(two_centuries_from_now))
  end

  def test_scope_found_after
    assert_equal(Observation.count,
                 Observation.found_after(start_of_time).count)
    assert_empty(Observation.found_after(two_centuries_from_now))
  end

  def test_scope_found_before
    assert_equal(Observation.count,
                 Observation.found_before(two_centuries_from_now).count)
    assert_empty(Observation.found_before(start_of_time))
  end

  def test_scope_found_between
    assert_equal(
      Observation.count,
      Observation.found_between(start_of_time, two_centuries_from_now).count
    )
    assert_empty(
      Observation.found_between(two_centuries_from_now, start_of_time)
    )
  end

  def test_scope_with_vote_by_user
    obs_with_vote_by_rolf = Observation.with_vote_by_user(users(:rolf))
    assert_includes(obs_with_vote_by_rolf,
                    observations(:coprinus_comatus_obs))
    assert_includes(Observation.with_vote_by_user(users(:mary)),
                    observations(:coprinus_comatus_obs))
    assert_not_includes(obs_with_vote_by_rolf,
                        observations(:peltigera_obs))
  end

  # There are no observation views in the fixtures
  def test_scope_reviewed_by_user
    ObservationView.create({ observation_id: observations(:fungi_obs).id,
                             user_id: users(:rolf).id,
                             reviewed: true })
    assert_includes(Observation.reviewed_by_user(users(:rolf)),
                    observations(:fungi_obs))
    assert_not_includes(Observation.reviewed_by_user(users(:rolf)),
                        observations(:peltigera_obs))
  end

  def test_scope_needs_id
    assert_includes(Observation.needs_id,
                    observations(:fungi_obs))
    assert_not_includes(Observation.needs_id,
                        observations(:peltigera_obs))
  end

  def test_scope_needs_id_for_user
    assert_includes(Observation.needs_id_for_user(users(:rolf)),
                    observations(:fungi_obs))
    assert_not_includes(Observation.needs_id_for_user(users(:rolf)),
                        observations(:peltigera_obs))
  end

  def test_scope_of_name
    assert_includes(Observation.of_name(names(:peltigera).id),
                    observations(:peltigera_obs))
    assert_not_includes(Observation.of_name(names(:fungi)),
                        observations(:peltigera_obs))
  end

  def test_scope_in_clade
    assert_includes(Observation.in_clade("Agaricales"),
                    observations(:coprinus_comatus_obs))
    assert_not_includes(Observation.in_clade("Agaricales"),
                        observations(:peltigera_obs))
    # test the scope can handle a genus
    assert_includes(Observation.in_clade("Tremella"),
                    observations(:owner_only_favorite_ne_consensus))
    assert_includes(Observation.in_clade("Tremella"),
                    observations(:sortable_obs_users_first_obs))
    assert_includes(Observation.in_clade("Tremella"),
                    observations(:sortable_obs_users_second_obs))
    assert_not_includes(Observation.in_clade("Tremella"),
                        observations(:chlorophyllum_rachodes_obs))
    # test the scope can handle a name instance
    assert_includes(Observation.in_clade(names(:coprinus)),
                    observations(:coprinus_comatus_obs))
  end

  def test_scope_by_user
    assert_includes(Observation.by_user(users(:mary)),
                    observations(:minimal_unknown_obs))
    assert_not_includes(Observation.by_user(users(:mary)),
                        observations(:coprinus_comatus_obs))
    assert_empty(Observation.by_user(users(:zero_user)))
  end

  def test_scope_of_name_of_look_alikes
    # Prove that Observations of look-alikes of <Name> include
    # Observations of other Names proposed for Observations of <Name>
    # NOTE: `of_look_alikes` is (currently) asymmetric / noncommunative. I.e.,
    # Observations of look-alikes of <Name> does NOT necessarily include
    # Observations of other Names suggested for Observations of <Name>

    # Ensure fixtures aren't broken before testing Observations of look-alikes
    tremella_obs = observations(:owner_only_favorite_ne_consensus)
    t_mesenterica_obs = observations(:sortable_obs_users_second_obs)
    assert_equal(names(:tremella), tremella_obs.name,
                 "Test needs different fixture")
    assert_equal(names(:tremella_mesenterica), t_mesenterica_obs.name,
                 "Test needs different fixture")
    # T. mesenterica was proposed for an Observation of Tremella
    assert_equal(namings(:tremella_mesenterica_naming).observation,
                 tremella_obs,
                 "Test needs different fixture")
    assert_includes(
      Observation.of_name(names(:tremella_mesenterica), of_look_alikes: true),
      tremella_obs,
      "Observations of look-alikes of <Name> should include " \
      "Observations of other Names for which <Name> was proposed"
    )
  end

  def test_scope_in_box
    cal = locations(:california)
    obss_in_cal_box = Observation.in_box(
      n: cal.north, s: cal.south, e: cal.east, w: cal.west
    )
    nybg = locations(:nybg_location)
    obss_in_nybg_box = Observation.in_box(
      n: nybg.north, s: nybg.south, e: nybg.east, w: nybg.west
    )
    obss_in_ecuador_box = Observation.in_box(
      n: 1.49397, s: -5.06906, e: -75.1904, w: -92.6038
    )
    quito_obs =
      Observation.create!(
        user: users(:rolf),
        lat: -0.1865944,
        long: -78.4305382,
        where: "Quito, Ecuador"
      )
    wrangel = locations(:east_lt_west_location)
    wrangel_obs =
      Observation.create!(
        user: users(:rolf),
        lat: (wrangel.north + wrangel.south) / 2,
        long: (wrangel.east + wrangel.west) / 2 + wrangel.west
      )
    obss_in_wrangel_box = Observation.in_box(
      n: wrangel.north, s: wrangel.south, e: wrangel.east, w: wrangel.west
    )

    # boxes not straddling 180 deg
    assert_includes(obss_in_cal_box,
                    observations(:unknown_with_lat_long))
    assert_includes(obss_in_ecuador_box,
                    quito_obs)
    assert_not_includes(obss_in_nybg_box,
                        observations(:unknown_with_lat_long))
    assert_not_includes(obss_in_cal_box,
                        observations(:minimal_unknown_obs),
                        "Observation without lat/lon should not be in box")

    # box straddling 180 deg
    assert_includes(obss_in_wrangel_box, wrangel_obs)
    assert_not_includes(obss_in_wrangel_box,
                        observations(:unknown_with_lat_long))

    assert_empty(Observation.where(lat: 0.001), "Test needs different fixture")
    assert_empty(Observation.in_box(n: 0.0001, s: 0.0001, e: 0.0001, w: 0),
                 "Observation.in_box should be empty if " \
                 "there are no Observations in the box")

    # invalid arguments
    assert_empty(
      Observation.in_box(n: cal.north, s: cal.south, e: cal.east),
      "`Observation.in_box` should be empty if an argument is missing"
    )
    assert_empty(
      Observation.in_box(n: 91, s: cal.south, e: cal.east, w: cal.west),
      "`Observation.in_box` should be empty if an argument is out of bounds"
    )
    assert_empty(
      Observation.in_box(n: cal.south - 10,
                         s: cal.south, e: cal.east, w: cal.west),
      "`Observation.in_box` should be empty if N < S"
    )
  end

  def test_scope_not_in_box
    cal = locations(:california)
    obss_not_in_cal_box = Observation.not_in_box(
      n: cal.north, s: cal.south, e: cal.east, w: cal.west
    )
    obs_with_burbank_geoloc = observations(:unknown_with_lat_long)

    nybg = locations(:nybg_location)
    obss_not_in_nybg_box = Observation.not_in_box(
      n: nybg.north, s: nybg.south, e: nybg.east, w: nybg.west
    )

    obss_not_in_ecuador_box = Observation.not_in_box(
      n: 1.49397, s: -5.06906, e: -75.1904, w: -92.6038
    )
    quito_obs =
      Observation.create!(
        user: users(:rolf),
        lat: -0.1865944,
        long: -78.4305382,
        where: "Quito, Ecuador"
      )

    wrangel = locations(:east_lt_west_location)
    wrangel_obs =
      Observation.create!(
        user: users(:rolf),
        lat: (wrangel.north + wrangel.south) / 2,
        long: (wrangel.east + wrangel.west) / 2 + wrangel.west
      )
    obss_not_in_wrangel_box = Observation.not_in_box(
      n: wrangel.north, s: wrangel.south, e: wrangel.east, w: wrangel.west
    )

    # boxes not straddling 180 deg
    assert_not_includes(obss_not_in_cal_box, obs_with_burbank_geoloc)
    assert_not_includes(obss_not_in_ecuador_box, quito_obs)
    assert_includes(obss_not_in_nybg_box, obs_with_burbank_geoloc)
    assert_includes(obss_not_in_cal_box, observations(:minimal_unknown_obs),
                    "Observation without lat/lon should not be in box")

    # box straddling 180 deg
    assert_not_includes(obss_not_in_wrangel_box, wrangel_obs)
    assert_includes(obss_not_in_wrangel_box, obs_with_burbank_geoloc)

    assert_equal(
      Observation.count,
      Observation.not_in_box(n: 0.0001, s: 0.0001, e: 0.0001, w: 0).count,
      "All Observations should be excluded from a tiny box in middle of nowhere"
    )

    # invalid arguments
    all_observations_count = Observation.count
    assert_equal(
      all_observations_count,
      Observation.not_in_box(n: cal.north, s: cal.south, e: cal.east).count,
      "All Observations should be excluded from a box with missing boundary"
    )
    assert_equal(
      all_observations_count,
      Observation.not_in_box(n: 91, s: cal.south,
                             e: cal.east, w: cal.west).count,
      "All Observations should be excluded from a box with an out-of-bounds arg"
    )
    assert_equal(
      all_observations_count,
      Observation.not_in_box(n: cal.south - 10, s: cal.south,
                             e: cal.east, w: cal.west).count,
      "All Observations should be excluded from box whose N < S"
    )
  end

  def test_scope_is_collection_location
    assert_includes(Observation.is_collection_location,
                    observations(:minimal_unknown_obs))
    assert_not_includes(Observation.is_collection_location,
                        observations(:displayed_at_obs))
  end

  def test_scope_has_notes_field
    assert_includes(Observation.has_notes_field("substrate"),
                    observations(:substrate_notes_obs))
    obs_substrate_in_plain_text =
      Observation.create!(notes: "The substrate is wood",
                          user: users(:rolf))
    assert_not_includes(Observation.has_notes_field("substrate"),
                        obs_substrate_in_plain_text)
    assert_empty(Observation.has_notes_field(ARBITRARY_SHA))
  end

  def test_scope_without_sequence
    assert_includes(Observation.without_sequence,
                    observations(:minimal_unknown_obs))
    assert_not_includes(Observation.without_sequence,
                        observations(:genbanked_obs))
  end

  def test_scope_confidence
    assert_includes(Observation.confidence(0, 0),
                    observations(:minimal_unknown_obs))
    assert_includes(Observation.confidence(0),
                    observations(:minimal_unknown_obs))
    assert_includes(Observation.confidence(0, 1),
                    observations(:minimal_unknown_obs))
    assert_includes(Observation.confidence(75, 100),
                    observations(:peltigera_obs))
    assert_equal(Observation.count, Observation.confidence(-100, 100).count)
    assert_empty(Observation.confidence(102, 103))
  end

  def test_scope_without_comments
    assert_includes(Observation.without_comments,
                    observations(:unlisted_rolf_obs))
    assert_not_includes(Observation.without_comments,
                        observations(:minimal_unknown_obs))
  end

  def test_scope_herbarium_record_notes_include
    obss_with_hr_notes =
      Observation.herbarium_record_notes_include("cleaned & dried at 115°")
    assert_includes(obss_with_hr_notes,
                    observations(:minimal_unknown_obs))
    assert_includes(obss_with_hr_notes,
                    observations(:detailed_unknown_obs))
    assert_not_includes(obss_with_hr_notes,
                        observations(:imageless_unvouchered_obs))
    assert_empty(Observation.herbarium_record_notes_include("ARBITRARY_SHA"))
  end

  def test_source_credit
    obs = observations(:coprinus_comatus_obs)
    assert_nil(obs.source)
    assert_nil(obs.source_credit)

    obs = observations(:detailed_unknown_obs)
    assert_equal("mo_website", obs.source)
    assert_equal(:source_credit_mo_website, obs.source_credit)

    obs = observations(:amateur_obs)
    assert_equal("mo_iphone_app", obs.source)
    assert_equal(:source_credit_mo_iphone_app, obs.source_credit)
  end
end
