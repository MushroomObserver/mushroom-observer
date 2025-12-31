# frozen_string_literal: true

require("test_helper")
# test Observation model
class ObservationTest < UnitTestCase
  include ActiveJob::TestHelper

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

  # ------------------------------------------
  #  Test owner id, favorites, NamingConsensus
  # ------------------------------------------

  def obs_consensus(fixture_name)
    Observation::NamingConsensus.new(observations(fixture_name))
  end

  # Only use this for one-off's. Re-use the consensus in a repeated test
  def change_vote(obs, naming, vote, user = User.current)
    consensus = ::Observation::NamingConsensus.new(obs)
    consensus.change_vote(naming, vote, user)
  end

  # Test Observer's Prefered ID
  def test_observer_preferred_id
    # obs = observations(:owner_only_favorite_ne_consensus)
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
    change_vote(vote.observation, vote.naming, Vote.min_pos_vote, vote.user)
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

    change_vote(obs, naming_top, Vote.delete_vote, user)
    old_2nd_choice.reload

    assert_equal(true, old_2nd_choice.favorite)
  end

  # Prove that when all an Observation's Namings are deprecated,
  # calc_consensus returns the synonym of the consensus with the highest vote.
  def test_calc_consensus_all_namings_deprecated
    obs = observations(:all_namings_deprecated_obs)
    winning_naming = namings(:all_namings_deprecated_winning_naming)
    consensus = Observation::NamingConsensus.new(obs)
    assert_equal(winning_naming, consensus.consensus_naming)
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
    atts = obs.attributes.symbolize_keys.slice(:id, :lat, :lng, :location_id)
    min_map = Mappable::MinimalObservation.new(atts)
    assert_objs_equal(locations(:burbank), min_map.location)
    assert_equal(locations(:burbank).id, min_map.location_id)

    # try passing the instance
    atts = atts.except(:location_id).merge(location: obs.location)
    min_map = Mappable::MinimalObservation.new(atts)
    assert_objs_equal(locations(:burbank), min_map.location)
    assert_equal(locations(:burbank).id, min_map.location_id)

    assert(min_map.observation?)
    assert_not(min_map.location?)
    assert_not(min_map.lat_lng_dubious?)

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
    # CommentAdd now uses deliver_later.
    User.current = rolf
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Comment.create(
        summary: "This is Rolf...",
        target: obs
      )
    end
    assert_equal(0, QueuedEmail.count)

    # Observation owner is not notified if naming added by themselves.
    # NameProposal now uses deliver_later.
    User.current = rolf
    new_naming = Naming.create(
      observation: obs,
      name: names(:agaricus_campestris),
      vote_cache: 0,
      user: rolf
    )
    assert_equal(0, QueuedEmail.count)
    assert_equal(names(:coprinus_comatus), obs.reload.name)

    # Observation owner is not notified if consensus changed by themselves.
    # ConsensusChange now uses deliver_later.
    User.current = rolf
    change_vote(obs, new_naming, 3)
    assert_equal(names(:agaricus_campestris), obs.reload.name)
    assert_equal(0, QueuedEmail.count)

    # Make Rolf opt out of all emails.
    rolf.email_comments_owner = false
    rolf.email_comments_response = false
    rolf.email_observations_naming = false
    rolf.email_observations_consensus = false
    assert_save(rolf)

    # Rolf should not be notified of anything here, either...
    # But Mary still will get something for having the naming.
    # CommentAdd now uses deliver_later.
    User.current = dick
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Comment.create(
        summary: "This is Dick...",
        target: obs.reload
      )
    end
    assert_equal(0, QueuedEmail.count)

    # NameProposal now uses deliver_later.
    # But Rolf opted out, so no email is sent.
    User.current = dick
    new_naming = Naming.create(
      observation: obs,
      name: names(:peltigera),
      vote_cache: 0,
      user: dick
    )
    assert_equal(0, QueuedEmail.count)
    assert_equal(names(:agaricus_campestris), obs.reload.name)

    # Make sure this changes consensus...
    dick.contribution = 2_000_000_000
    assert_save(dick)

    # ConsensusChange now uses deliver_later.
    # But Rolf opted out, so no email is sent.
    User.current = dick
    change_vote(obs, new_naming, 3)
    assert_equal(names(:peltigera), obs.reload.name)
    assert_equal(0, QueuedEmail.count)
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
    # CommentAdd now uses deliver_later.
    # (Rolf owns observations(:coprinus_comatus_obs),
    # one naming, two votes, conf. around 1.5.)
    rolf.email_comments_owner = true
    assert_save(rolf)
    User.current = mary
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Comment.create(
        summary: "This is Mary...",
        target: obs
      )
    end
    assert_equal(0, QueuedEmail.count)

    # Observation owner is notified if naming added by someone else.
    # NameProposal now uses deliver_later.
    rolf.email_comments_owner = false
    rolf.email_observations_naming = true
    assert_save(rolf)
    User.current = mary
    new_naming = nil
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      new_naming = Naming.create(
        observation: obs.reload,
        name: names(:agaricus_campestris),
        vote_cache: 0,
        user: mary
      )
    end
    # QueuedEmail stays at 0 (CommentAdd, NameProposal now via deliver_later)
    assert_equal(0, QueuedEmail.count)

    # Observation owner is notified if consensus changed by someone else.
    # ConsensusChange now uses deliver_later.
    rolf.email_observations_naming = false
    rolf.email_observations_consensus = true
    assert_save(rolf)

    # Gang up on Rolf
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      change_vote(obs, new_naming, 3, dick)
      change_vote(obs, new_naming, 3, katrina)
      change_vote(obs, namings(:coprinus_comatus_naming), -3, katrina)
    end
    # QueuedEmail count stays at 0 (all via deliver_later)
    assert_equal(0, QueuedEmail.count)

    # Make sure Mary gets notified if Rolf responds to her comment.
    # CommentAdd now uses deliver_later.
    mary.email_comments_response = true
    assert_save(mary)
    User.current = rolf
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Comment.create(
        summary: "This is Rolf...",
        target: observations(:coprinus_comatus_obs)
      )
    end
    assert_equal(0, QueuedEmail.count)
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
    # CommentAdd now uses deliver_later.
    # (Rolf owns observations(:coprinus_comatus_obs),
    # one naming, two votes, conf. around 1.5.)
    User.current = mary
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Comment.create(
        summary: "This is Mary...",
        target: observations(:coprinus_comatus_obs)
      )
    end
    assert_equal(0, QueuedEmail.count)

    # Watcher is notified if naming added.
    # NameProposal now uses deliver_later.
    User.current = mary
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      Naming.create(
        observation: observations(:coprinus_comatus_obs),
        name: names(:agaricus_campestris),
        vote_cache: 0,
        user: mary
      )
    end
    # QueuedEmail count stays at 0 (all via deliver_later)
    assert_equal(0, QueuedEmail.count)

    # Watcher is notified if consensus changed.
    # ConsensusChange now uses deliver_later.
    User.current = rolf
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      change_vote(obs, namings(:coprinus_comatus_other_naming), 3, rolf)
    end
    assert_equal(3,
                 votes(:coprinus_comatus_other_naming_rolf_vote).reload.value)
    assert_save(votes(:coprinus_comatus_other_naming_rolf_vote))
    # QueuedEmail count stays at 0 (all via deliver_later)
    assert_equal(0, QueuedEmail.count)

    # Now have Rolf make a bunch of changes...
    User.current = rolf

    # Watcher is also notified of changes in the observation.
    # ObservationChange now uses deliver_later, so we test enqueued emails.
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      obs.notes = "I have new information on this observation."
      obs.save
    end
    # QueuedEmail count stays at 0 (all via deliver_later)
    assert_equal(0, QueuedEmail.count)

    # Make sure subsequent changes also enqueue emails.
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      obs.where = "Somewhere else"
      obs.save
    end
    assert_equal(0, QueuedEmail.count)

    # Same deal with adding and removing images.
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      obs.add_image(images(:disconnected_coprinus_comatus_image))
    end
    assert_equal(0, QueuedEmail.count)
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      obs.remove_image(images(:disconnected_coprinus_comatus_image))
    end
    assert_equal(0, QueuedEmail.count)
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
    # ObservationChange now uses deliver_later.
    marys_interest.state = true
    assert_save(marys_interest)

    User.current = rolf
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      observations(:coprinus_comatus_obs).
        notes = "I have new information on this observation."
      observations(:coprinus_comatus_obs).save
    end
    assert_equal(0, QueuedEmail.count)

    # Add image to observation.
    marys_interest.state = false
    assert_save(marys_interest)
    dicks_interest.state = true
    assert_save(dicks_interest)
    User.current = rolf
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      obs.reload.add_image(images(:disconnected_coprinus_comatus_image))
    end
    assert_equal(0, QueuedEmail.count)

    # Destroy observation.
    dicks_interest.state = false
    assert_save(dicks_interest)
    katrinas_interest.state = true
    assert_save(katrinas_interest)

    User.current = rolf
    assert_equal(0, QueuedEmail.count)
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      obs.reload.destroy
    end
    assert_equal(0, QueuedEmail.count)
    QueuedEmail.queue = false
  end

  def test_email_notification_is_collection_location_change
    NameTracker.all.map(&:destroy)
    QueuedEmail.queue = true

    obs = observations(:coprinus_comatus_obs)
    Interest.create(target: obs, user: mary, state: true)

    User.current = rolf
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      obs.update(is_collection_location: !obs.is_collection_location)
    end
    assert_equal(0, QueuedEmail.count)
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
      name_id: @fungi.id,
      needs_naming: true,
      user: rolf
    )

    User.current = rolf
    namg1 = Naming.create!(
      observation_id: obs.id,
      name_id: @name1.id,
      user: rolf
    )

    User.current = mary
    namg2 = Naming.create!(
      observation_id: obs.id,
      name_id: @name2.id,
      user: mary
    )

    User.current = dick
    namg3 = Naming.create!(
      observation_id: obs.id,
      name_id: @name3.id,
      user: dick
    )

    namings = [namg1, namg2, namg3]

    # Okay, nothing has votes yet.
    obs.reload
    consensus = Observation::NamingConsensus.new(obs)
    assert_equal(@fungi, obs.name)
    assert_nil(consensus.consensus_naming)
    assert_not(consensus.owner_voted?(namg1))
    assert_not(consensus.user_voted?(namg1, rolf))
    assert_not(consensus.user_voted?(namg1, mary))
    assert_not(consensus.user_voted?(namg1, dick))
    assert_nil(consensus.users_vote(namg1, obs.user))
    assert_nil(consensus.users_vote(namg1, rolf))
    assert_nil(consensus.users_vote(namg1, mary))
    assert_nil(consensus.users_vote(namg1, dick))
    assert_not(consensus.users_favorite?(namg1, rolf))
    assert_not(consensus.users_favorite?(namg1, mary))
    assert_not(consensus.users_favorite?(namg1, dick))

    # They're all the same, none with votes yet, so first apparently wins.
    consensus.calc_consensus
    obs.reload
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, consensus.consensus_naming)
    # None of the crew has reviewed the obs.
    rov = ObservationView.find_by(observation_id: obs.id, user_id: rolf.id)
    mov = ObservationView.find_by(observation_id: obs.id, user_id: mary.id)
    dov = ObservationView.find_by(observation_id: obs.id, user_id: mary.id)
    assert_nil(rov)
    assert_nil(mov)
    assert_nil(dov)

    # Play with Rolf's vote for his naming (first naming).
    User.current = rolf # necessary for ov creation in naming_consensus
    consensus.change_vote(namg1, 2, rolf)
    namg1.reload
    obs.reload
    assert(consensus.owner_voted?(namg1))
    assert(consensus.user_voted?(namg1, rolf))

    assert(vote = consensus.users_vote(namg1, obs.user))
    assert_equal(vote, consensus.users_vote(namg1, rolf))
    assert(consensus.owners_favorite?(namg1))
    assert(consensus.users_favorite?(namg1, rolf))
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, consensus.consensus_naming)
    # Check that the obs no longer `needs_naming`
    assert_equal(false, obs.needs_naming)

    consensus.change_vote(namg1, 0.01, rolf)
    namg1.reload
    obs.reload
    assert(consensus.owners_favorite?(namg1))
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, consensus.consensus_naming)

    consensus.change_vote(namg1, -0.01, rolf)
    namg1.reload
    obs.reload
    assert_not(consensus.owners_favorite?(namg1))
    assert_not(consensus.users_favorite?(namg1, rolf))
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, consensus.consensus_naming)
    # Check that the obs again `needs_naming`
    assert_equal(true, obs.needs_naming)

    # Play with Rolf's vote for other namings.
    # Make votes namg1: -0.01, namg2: 1, namg3: 0
    consensus.change_vote(namg2, 1, rolf)
    namings.each(&:reload)
    namg2.reload
    obs.reload
    assert_not(consensus.owners_favorite?(namg1))
    assert(consensus.owners_favorite?(namg2))
    assert_not(consensus.owners_favorite?(namg3))
    assert_names_equal(@name2, obs.name)
    assert_equal(namg2, consensus.consensus_naming)
    # Check that the obs again does not `needs_naming`
    assert_equal(false, obs.needs_naming)

    # Make votes namg1: -0.01, namg2: 1, namg3: 2
    consensus.change_vote(namg3, 2, rolf)
    namings.each(&:reload)
    obs.reload
    assert_not(consensus.owners_favorite?(namg1))
    assert_not(consensus.owners_favorite?(namg2))
    assert(consensus.owners_favorite?(namg3))
    assert_names_equal(@name3, obs.name)
    assert_equal(namg3, consensus.consensus_naming)

    # Make votes namg1: 3, namg2: 1, namg3: 2
    consensus.change_vote(namg1, 3, rolf)
    namings.each(&:reload)
    obs.reload
    assert(consensus.owners_favorite?(namg1))
    assert_not(consensus.owners_favorite?(namg2))
    assert_not(consensus.owners_favorite?(namg3))
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, consensus.consensus_naming)

    # Make votes namg1: 1, namg2: 1, namg3: 2
    consensus.change_vote(namg1, 1, rolf)
    namings.each(&:reload)
    obs.reload
    assert_not(consensus.owners_favorite?(namg1))
    assert_not(consensus.owners_favorite?(namg2))
    assert(consensus.owners_favorite?(namg3))
    assert_names_equal(@name3, obs.name)
    assert_equal(namg3, consensus.consensus_naming)

    # Play with Mary's vote. Make votes:
    User.current = mary # necessary for ov creation in naming_consensus
    # namg1 Agaricus campestris L.: rolf=1.0, mary=1.0
    # namg2 Coprinus comatus (O.F. Müll.) Pers.: rolf=1.0, mary=2.0(*)
    # namg3 Conocybe filaris: rolf=2.0(*), mary=-1.0
    consensus.change_vote(namg1, 1, mary)
    consensus.change_vote(namg2, 2, mary)
    consensus.change_vote(namg3, -1, mary)
    namings.each(&:reload)
    obs.reload
    assert_not(consensus.users_favorite?(namg1, mary))
    assert(consensus.users_favorite?(namg2, mary))
    assert_not(consensus.users_favorite?(namg3, mary))
    assert_names_equal(@name2, obs.name)
    assert_equal(namg2, consensus.consensus_naming)

    # namg1 Agaricus campestris L.: rolf=1.0, mary=1.0(*)
    # namg2 Coprinus comatus (O.F. Müll.) Pers.: rolf=1.0, mary=0.01
    # namg3 Conocybe filaris: rolf=2.0(*), mary=-1.0
    consensus.change_vote(namg2, 0.01, mary)
    namings.each(&:reload)
    obs.reload
    assert(consensus.users_favorite?(namg1, mary))
    assert_not(consensus.users_favorite?(namg2, mary))
    assert_not(consensus.users_favorite?(namg3, mary))
    assert_names_equal(@name1, obs.name)
    assert_equal(namg1, consensus.consensus_naming)

    consensus.change_vote(namg1, -0.01, mary)
    namings.each(&:reload)
    obs.reload
    assert_not(consensus.users_favorite?(namg1, mary))
    assert(consensus.users_favorite?(namg2, mary))
    assert_not(consensus.users_favorite?(namg3, mary))
    assert_not(consensus.users_favorite?(namg1, rolf))
    assert_not(consensus.users_favorite?(namg2, rolf))
    assert(consensus.users_favorite?(namg3, rolf))
    assert_not(consensus.users_favorite?(namg1, dick))
    assert_not(consensus.users_favorite?(namg2, dick))
    assert_not(consensus.users_favorite?(namg3, dick))
    assert_names_equal(@name3, obs.name)
    assert_equal(namg3, consensus.consensus_naming)

    # Check that the obs no longer `needs_naming`
    assert_equal(false, obs.needs_naming)

    # Check that this whole thing marked the obs as reviewed in the ov table
    # for both Rolf and Mary
    rov = ObservationView.find_by(observation_id: obs.id, user_id: rolf.id)
    mov = ObservationView.find_by(observation_id: obs.id, user_id: mary.id)
    assert_equal(true, rov.reviewed)
    assert_equal(true, mov.reviewed)
  end

  def test_refresh_needs_naming_column
    Observation.update_all(needs_naming: 0)
    Observation.refresh_needs_naming_column
    assert_equal(true, observations(:minimal_unknown_obs).needs_naming)
    assert_equal(true, observations(:detailed_unknown_obs).needs_naming)
    assert_equal(false, observations(:coprinus_comatus_obs).needs_naming)
    assert_equal(true, observations(:agaricus_campestris_obs).needs_naming)
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

    # has species_list
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
      user_id: rolf.id
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
    parts = ["Cap", "Nearby trees", "odor", "orphaned caption", "Other"]
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
    parts = ["Cap", "Nearby trees", "odor", "orphaned caption", "Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))

    # template and notes for a template part, orphaned part, Other,
    # with order scrambled in the Observation
    obs   = observations(:template_and_orphaned_notes_scrambled_obs)
    parts = ["Cap", "Nearby trees", "odor", "orphaned caption 1",
             "orphaned caption 2", "Collector", "Other"]
    assert_equal(parts, obs.form_notes_parts(obs.user))
  end

  # Prove that part value is returned for the given key,
  # including any required normalization of the key
  def test_notes_parts_values
    obs = observations(:template_and_orphaned_notes_scrambled_obs)
    assert_equal("red", obs.notes_part_value("Cap"))
    assert_equal("pine", obs.notes_part_value("Nearby trees"))
  end

  # nil notes were seen in the wild
  def test_notes_nil
    User.current = mary
    obs = Observation.create!(name_id: names(:fungi).id, when_str: "2020-07-05",
                              notes: nil, user: mary)

    assert_nothing_raised do
      obs.notes[:Collector]
    rescue StandardError => e
      flunk(
        "It shouldn't throw \"#{e.message}\" when reading part of a nil Note"
      )
    end
  end

  # empty string notes were seen in the wild
  def test_notes_empty_string
    User.current = mary
    obs = Observation.create!(name_id: names(:fungi).id,
                              when_str: "2020-07-05", notes: "",
                              user: mary)
    assert_nothing_raised do
      obs.notes[:Collector]
    rescue StandardError => e
      flunk(
        "It shouldn't throw \"#{e.message}\" when reading part of " \
        "a Note that's an empty string"
      )
    end
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
    obs = observations(:unknown_with_lat_lng)
    assert_equal(34.1622, obs.lat)
    assert_equal(-118.3521, obs.lng)
    assert_equal(34.1622, obs.public_lat)
    assert_equal(-118.3521, obs.public_lng)

    obs.update_attribute(:gps_hidden, true)
    assert_nil(obs.public_lat)
    assert_nil(obs.public_lng)
    obs.current_user = obs.user
    assert_equal(34.1622, obs.public_lat)
    assert_equal(-118.3521, obs.public_lng)
  end

  def test_place_name_and_coordinates_with_values
    obs = observations(:amateur_obs)
    assert_equal(obs.place_name_and_coordinates,
                 "Pasadena, California, USA (34.1622°N 118.3521°W)")
  end

  def test_place_name_and_coordinates_has_no_values
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
      Observation.create!(name_id: fungi.id, when: Time.zone.today + 2.days,
                          user: mary)
    end
    assert_match(:validate_future_time.t, exception.message)
  end

  def test_check_requirements_future_time
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      # Note that 'when' gets automagically converted to Date
      Observation.create!(name_id: fungi.id, when: 2.days.from_now,
                          user: mary)
    end
    assert_match(:validate_future_time.t, exception.message)
  end

  def test_check_requirements_invalid_year
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, when: Date.new(1499, 1, 1),
                          user: mary)
    end
    assert_match(:validate_invalid_year.t, exception.message)
  end

  def test_check_requirements_where_too_long
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, where: "X" * 1025,
                          user: mary)
    end
    assert_match(:validate_observation_where_too_long.t, exception.message)
  end

  def test_check_requirements_where_no_latitude
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, lng: 90.0, user: mary)
    end
    assert_match(:runtime_lat_long_error.t, exception.message)
  end

  def test_check_requirements_where_no_longitude
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, lat: 90.0, user: mary)
    end
    assert_match(:runtime_lat_long_error.t, exception.message)
  end

  def test_check_requirements_where_bad_altitude
    User.current = mary
    fungi = names(:fungi)
    # Currently all strings are parsable as altitude
    assert_nothing_raised do
      Observation.create!(name_id: fungi.id, alt: "This should be bad",
                          user: mary)
    end
  end

  def test_check_requirements_with_valid_when_str
    User.current = mary
    fungi = names(:fungi)
    assert_nothing_raised do
      Observation.create!(name_id: fungi.id, when_str: "2020-07-05",
                          user: mary)
    end
  end

  def test_check_requirements_with_invalid_when_str_date
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, when_str: "0000-00-00",
                          user: mary)
    end
    assert_match(:runtime_date_invalid.t, exception.message)
  end

  def test_check_requirements_with_invalid_when_str
    User.current = mary
    fungi = names(:fungi)
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      Observation.create!(name_id: fungi.id, when_str: "This is not a date",
                          user: mary)
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

  def long_ago
    (Time.zone.today - 400.years).strftime("%Y-%m-%d")
  end

  def a_century_from_now
    (Time.zone.today + 100.years).strftime("%Y-%m,-%d")
  end

  def two_centuries_from_now
    (Time.zone.today + 200.years).strftime("%Y-%m-%d")
  end

  def test_scope_found_on
    obs = observations(:minimal_unknown_obs)
    assert_includes(Observation.found_on(obs.when.to_s), obs)
    assert_empty(Observation.found_on(two_centuries_from_now))
  end

  def test_scope_found_after
    assert_equal(Observation.count,
                 Observation.found_after(long_ago).count)
    assert_empty(Observation.found_after(two_centuries_from_now))
  end

  def test_scope_found_before
    assert_equal(Observation.count,
                 Observation.found_before(two_centuries_from_now).count)
    assert_empty(Observation.found_before(long_ago))
  end

  def test_scope_found_between
    assert_equal(
      Observation.count,
      Observation.found_between(long_ago, two_centuries_from_now).count
    )
    assert_empty(
      Observation.found_between(two_centuries_from_now, long_ago)
    )
  end

  def test_scope_with_vote_by_user
    obs_with_vote_by_rolf = Observation.with_vote_by_user(rolf)
    assert_includes(obs_with_vote_by_rolf,
                    observations(:coprinus_comatus_obs))
    assert_includes(Observation.with_vote_by_user(users(:mary)),
                    observations(:coprinus_comatus_obs))
    assert_not_includes(obs_with_vote_by_rolf,
                        observations(:peltigera_obs))
  end

  def test_scope_without_vote_by_user
    obs = Observation.without_vote_by_user(rolf)
    assert_not_includes(obs, observations(:coprinus_comatus_obs))
    assert_includes(obs, observations(:peltigera_obs))
  end

  # There are no observation views in the fixtures
  def test_scope_reviewed_by_user
    ObservationView.create({ observation_id: observations(:fungi_obs).id,
                             user_id: rolf.id,
                             reviewed: true })
    assert_includes(Observation.reviewed_by_user(rolf),
                    observations(:fungi_obs))
    assert_not_includes(Observation.reviewed_by_user(rolf),
                        observations(:peltigera_obs))
  end

  def test_scope_needs_naming_generally
    assert_includes(Observation.needs_naming_generally,
                    observations(:fungi_obs))
    assert_not_includes(Observation.needs_naming_generally,
                        observations(:peltigera_obs))
  end

  def test_scope_needs_naming
    assert_includes(
      Observation.needs_naming(rolf),
      observations(:fungi_obs)
    )
    assert_not_includes(
      Observation.needs_naming(rolf),
      observations(:peltigera_obs)
    )
  end

  # Regression test for NOT IN NULL bug
  # When observation_views contains a NULL observation_id, the NOT IN clause
  # in not_reviewed_by_user returns no results due to NULL semantics
  def test_scope_not_reviewed_by_user_with_null_observation_id
    # Create a NULL observation_id record in observation_views for rolf
    # This simulates data corruption or a bug that allowed NULL to be inserted
    ObservationView.create!(
      observation_id: nil,
      user_id: rolf.id,
      reviewed: true,
      last_view: Time.zone.now
    )

    # fungi_obs needs naming and rolf hasn't reviewed it
    # This should still be included even with the NULL record
    result = Observation.needs_naming(rolf)
    assert_includes(
      result,
      observations(:fungi_obs),
      "needs_naming scope should return observations even when " \
      "observation_views contains NULL observation_id for the user"
    )
  end

  def test_scope_names
    assert_includes(Observation.names(lookup: names(:peltigera).id),
                    observations(:peltigera_obs))
    assert_not_includes(Observation.names(lookup: names(:fungi)),
                        observations(:peltigera_obs))
  end

  def test_scope_clade
    assert_includes(Observation.clade("Agaricales"),
                    observations(:coprinus_comatus_obs))
    assert_not_includes(Observation.clade("Agaricales"),
                        observations(:peltigera_obs))
    # test the scope can handle a genus
    assert_includes(Observation.clade("Tremella"),
                    observations(:owner_only_favorite_ne_consensus))
    assert_includes(Observation.clade("Tremella"),
                    observations(:sortable_obs_users_first_obs))
    assert_includes(Observation.clade("Tremella"),
                    observations(:sortable_obs_users_second_obs))
    assert_not_includes(Observation.clade("Tremella"),
                        observations(:chlorophyllum_rachodes_obs))
    # test the scope can handle a name instance
    assert_includes(Observation.clade(names(:coprinus)),
                    observations(:coprinus_comatus_obs))
  end

  def test_scope_by_users
    assert_includes(Observation.by_users(users(:mary)),
                    observations(:minimal_unknown_obs))
    assert_not_includes(Observation.by_users(users(:mary)),
                        observations(:coprinus_comatus_obs))
    assert_empty(Observation.by_users(users(:zero_user)))
  end

  def test_scope_of_name_of_look_alikes
    # Prove that Observations of look-alikes of <Name> include
    # Observations of other Names proposed for Observations of <Name>
    # NOTE: `exclude_consensus` is (currently) asymmetric / noncommunative.
    # I.e., Observations of look-alikes of <Name> does NOT necessarily include
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
      Observation.names(lookup: names(:tremella_mesenterica),
                        exclude_consensus: true),
      tremella_obs,
      "Observations of look-alikes of <Name> should include " \
      "Observations of other Names for which <Name> was proposed"
    )
  end

  def test_scope_has_location
    loc = Observation.where(location_id: locations(:nybg_location)).first
    no_loc = Observation.where(location_id: nil).first
    assert_includes(
      Observation.has_location, loc,
      "Observations has_location should include obs at defined location."
    )
    assert_not_includes(
      Observation.has_location, no_loc,
      "Observations has_location should not include obs with no location."
    )
    assert_includes(
      Observation.has_location(false), no_loc,
      "Observations has_location(false) should include obs with no location."
    )
    assert_not_includes(
      Observation.has_location(false), loc,
      "Observations has_location(false) should not include obs with location."
    )
  end

  def test_scope_has_geolocation
    geoloc = Observation.where.not(lat: nil).first
    no_geoloc = Observation.where(lat: nil).first
    assert_includes(
      Observation.has_geolocation, geoloc,
      "Observations has_geolocation should include obs with latitude."
    )
    assert_not_includes(
      Observation.has_geolocation, no_geoloc,
      "Observations has_geolocation should not include obs with no latitude."
    )
    assert_includes(
      Observation.has_geolocation(false), no_geoloc,
      "Observations has_geolocation(false) should include obs with no latitude."
    )
    assert_not_includes(
      Observation.has_geolocation(false), geoloc,
      "Observations has_geolocation(false) shouldn't include obs with latitude."
    )
  end

  def test_scope_location_undefined
    results = Observation.location_undefined
    top_undefined = "Briceland, California, USA"
    # results.count gives counts of each result
    assert_equal(top_undefined, results.first.where)
    assert_equal(
      results.count.first[1],
      Observation.where(where: top_undefined).has_location(false).count
    )
  end

  def nybg
    @nybg ||= locations(:nybg_location)
  end

  def nybg_box
    @nybg_box ||= nybg.bounding_box
  end

  def cal
    @cal ||= locations(:california)
  end

  def cal_box
    @cal_box ||= cal.bounding_box
  end

  def wrangel
    @wrangel ||= locations(:east_lt_west_location)
  end

  # { north: 71.588, south: 70.759, west: 178.648, east: -177.433 }
  def wrangel_box
    @wrangel_box ||= wrangel.bounding_box
  end

  def ecuador_box
    @ecuador_box ||=
      { north: 1.49397, south: -5.06906, east: -75.1904, west: -92.6038 }
  end

  def tiny_box
    e = MO.box_epsilon
    @tiny_box ||= { north: e, south: e, east: e, west: 0 }
  end

  def missing_west_box
    @missing_west_box ||= { north: cal.north, south: cal.south, east: cal.east }
  end

  def outta_bounds_box
    @outta_bounds_box ||=
      { north: 91, south: cal.south, east: cal.east, west: cal.west }
  end

  def north_souther_than_south_box
    @north_souther_than_south_box ||= cal_box.merge(north: cal.south - 10)
  end

  def test_scope_in_box
    obss_in_cal_box = Observation.in_box(**cal_box)
    obss_in_nybg_box = Observation.in_box(**nybg_box)
    quito_obs =
      Observation.create!(
        user: rolf,
        lat: -0.1865944,
        lng: -78.4305382,
        where: "Quito, Ecuador"
      )
    obss_in_ecuador_box = Observation.in_box(**ecuador_box)

    wrangel_obs =
      Observation.create!(
        user: rolf,
        lat: (wrangel.north + wrangel.south) / 2,
        lng: (wrangel.east + wrangel.west) / 2 + wrangel.west,
        where: "Wrangel Island, Russia"
      )
    # lat: 34.1622 lng: -118.3521
    unknown_lat_lng_obs = observations(:unknown_with_lat_lng)
    minimal_unknown_obs = observations(:minimal_unknown_obs)
    obss_in_wrangel_box = Observation.in_box(**wrangel_box)

    # Tests are comparing IDs so the results are legible in the event of failure
    # boxes not straddling 180 deg
    assert_includes(obss_in_cal_box.map(&:id), unknown_lat_lng_obs.id)
    assert_includes(obss_in_ecuador_box.map(&:id), quito_obs.id)
    assert_not_includes(obss_in_nybg_box.map(&:id), unknown_lat_lng_obs.id)
    assert_not_includes(obss_in_cal_box.map(&:id), minimal_unknown_obs.id,
                        "Observation without lat/lon should not be in box")

    # box straddling 180 deg
    assert_includes(obss_in_wrangel_box.map(&:id), wrangel_obs.id)
    assert_not_includes(obss_in_wrangel_box.map(&:id), unknown_lat_lng_obs.id)

    assert_empty(Observation.where(lat: 0.001), "Test needs different fixture")
    assert_empty(
      Observation.in_box(**tiny_box),
      "Observation.in_box should be empty if " \
      "there are no Observations in the box"
    )

    # invalid arguments
    assert_empty(
      Observation.in_box(**missing_west_box),
      "`Observation.in_box` should be empty if an argument is missing"
    )
    assert_empty(
      Observation.in_box(**outta_bounds_box),
      "`Observation.in_box` should be empty if an argument is out of bounds"
    )
    assert_empty(
      Observation.in_box(**north_souther_than_south_box),
      "`Observation.in_box` should be empty if N < S"
    )
  end

  def test_scope_in_box_with_taxon
    args = { north: "36.2718",
             south: "29.852",
             east: "-82.92729999999999",
             west: "-96.3512" }
    obs = Observation.names(lookup: names(:coprinus)).in_box(**args)
    assert_not(obs.count.negative?)
  end

  def test_scope_in_box_over_dateline_with_taxon
    args = { north: "36.2718",
             south: "29.852",
             east: "-82.92729999999999",
             west: "9.3512" }
    obs = Observation.names(lookup: names(:coprinus)).in_box(**args)
    assert_not(obs.count.negative?)
  end

  def test_scope_in_box_with_taxon_vague
    args = { vague: 1,
             north: "36.2718",
             south: "29.852",
             east: "-82.92729999999999",
             west: "-96.3512" }
    obs = Observation.names(lookup: names(:coprinus)).in_box(**args)
    assert_not(obs.count.negative?)
  end

  def test_scope_in_box_over_dateline_with_taxon_vague
    args = { vague: 1,
             north: "36.2718",
             south: "29.852",
             east: "-82.92729999999999",
             west: "9.3512" }
    obs = Observation.names(lookup: names(:coprinus)).in_box(**args)
    assert_not(obs.count.negative?)
  end

  def test_scope_not_in_box
    obs_with_burbank_geoloc = observations(:unknown_with_lat_lng)
    obss_not_in_cal_box = Observation.not_in_box(**cal_box)
    obss_not_in_nybg_box = Observation.not_in_box(**nybg_box)

    quito_obs =
      Observation.create!(
        user: rolf,
        lat: -0.1865944,
        lng: -78.4305382,
        where: "Quito, Ecuador"
      )
    obss_not_in_ecuador_box = Observation.not_in_box(**ecuador_box)

    wrangel_obs =
      Observation.create!(
        user: rolf,
        lat: (wrangel.north + wrangel.south) / 2,
        lng: (wrangel.east + wrangel.west) / 2 + wrangel.west,
        where: "Wrangel Island, Russia"
      )
    minimal_unknown_obs = observations(:minimal_unknown_obs)
    obss_not_in_wrangel_box = Observation.not_in_box(**wrangel_box)

    # Tests are comparing IDs so the results are legible in the event of failure
    # boxes not straddling 180 deg
    assert_not_includes(obss_not_in_cal_box.map(&:id),
                        obs_with_burbank_geoloc.id)
    assert_not_includes(obss_not_in_ecuador_box.map(&:id), quito_obs.id)
    assert_includes(obss_not_in_nybg_box.map(&:id), obs_with_burbank_geoloc.id)
    assert_includes(obss_not_in_cal_box.map(&:id), minimal_unknown_obs.id,
                    "Observation without lat/lon should not be in box")

    # box straddling 180 deg
    assert_not_includes(obss_not_in_wrangel_box.map(&:id), wrangel_obs.id)
    assert_includes(obss_not_in_wrangel_box.map(&:id),
                    obs_with_burbank_geoloc.id)

    assert_equal(
      Observation.count,
      Observation.not_in_box(**tiny_box).count,
      "All Observations should be excluded from a tiny box in middle of nowhere"
    )

    # invalid arguments
    all_observations_count = Observation.count
    assert_equal(
      all_observations_count,
      Observation.not_in_box(**missing_west_box).count,
      "All Observations should be excluded from a box with missing boundary"
    )
    assert_equal(
      all_observations_count,
      Observation.not_in_box(**outta_bounds_box).count,
      "All Observations should be excluded from a box with an out-of-bounds arg"
    )
    assert_equal(
      all_observations_count,
      Observation.not_in_box(**north_souther_than_south_box).count,
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
                          user: rolf)
    assert_not_includes(Observation.has_notes_field("substrate"),
                        obs_substrate_in_plain_text)
    assert_empty(Observation.has_notes_field(ARBITRARY_SHA))
  end

  def test_scope_has_sequences
    assert_includes(Observation.has_sequences,
                    observations(:genbanked_obs))
    assert_not_includes(Observation.has_sequences,
                        observations(:minimal_unknown_obs))
  end

  def test_scope_has_field_slips
    # minimal_unknown_obs has field_slip_one in fixtures
    assert_includes(Observation.has_field_slips(true),
                    observations(:minimal_unknown_obs))
    # coprinus_comatus_obs has no field slips
    assert_not_includes(Observation.has_field_slips(true),
                        observations(:coprinus_comatus_obs))

    # Test false - should return observations WITHOUT field slips
    assert_includes(Observation.has_field_slips(false),
                    observations(:coprinus_comatus_obs))
    assert_not_includes(Observation.has_field_slips(false),
                        observations(:minimal_unknown_obs))
  end

  def test_scope_has_collection_numbers
    # minimal_unknown_obs has minimal_unknown_coll_num in fixtures
    assert_includes(Observation.has_collection_numbers(true),
                    observations(:minimal_unknown_obs))
    # peltigera_obs has no collection numbers
    assert_not_includes(Observation.has_collection_numbers(true),
                        observations(:peltigera_obs))

    # Test false - should return observations WITHOUT collection numbers
    assert_includes(Observation.has_collection_numbers(false),
                    observations(:peltigera_obs))
    assert_not_includes(Observation.has_collection_numbers(false),
                        observations(:minimal_unknown_obs))
  end

  def test_scope_has_comments
    # minimal_unknown_obs has comments in fixtures
    assert_includes(Observation.has_comments,
                    observations(:minimal_unknown_obs))
    # unlisted_rolf_obs has no comments
    assert_not_includes(Observation.has_comments,
                        observations(:unlisted_rolf_obs))

    # Test false - should return observations WITHOUT comments
    assert_includes(Observation.has_comments(false),
                    observations(:unlisted_rolf_obs))
    assert_not_includes(Observation.has_comments(false),
                        observations(:minimal_unknown_obs))
  end

  def test_scope_has_sequences_false
    assert_includes(Observation.has_sequences(false),
                    observations(:minimal_unknown_obs))
    assert_not_includes(Observation.has_sequences(false),
                        observations(:genbanked_obs))
  end

  def test_scope_confidence
    assert_includes(Observation.confidence(0, 0),
                    observations(:minimal_unknown_obs))
    assert_includes(Observation.confidence(0),
                    observations(:minimal_unknown_obs))
    assert_includes(Observation.confidence(0, 1),
                    observations(:minimal_unknown_obs))
    assert_includes(Observation.confidence(2.4, 3),
                    observations(:peltigera_obs))
    assert_includes(Observation.confidence([2.4, 3]), # array
                    observations(:peltigera_obs))
    assert_equal(Observation.count, Observation.confidence(-3, 3).count)
    assert_empty(Observation.confidence(3.1, 3.2))
  end

  def test_scope_confidence_single_value_ranges
    # Single positive values should search for range (next_lower, value]
    # "Promising" (2.0) should match vote_cache > 1.0 AND <= 2.0
    promising_results = Observation.confidence(2.0)
    promising_results.each do |obs|
      assert(obs.vote_cache > 1.0,
             "vote_cache should be > 1.0, got #{obs.vote_cache}")
      assert(obs.vote_cache <= 2.0,
             "vote_cache should be <= 2.0, got #{obs.vote_cache}")
    end

    # Single negative values should search for range [value, next_higher)
    # "Doubtful" (-1.0) should match vote_cache >= -1.0 AND < 0.0
    doubtful_results = Observation.confidence(-1.0)
    doubtful_results.each do |obs|
      assert(obs.vote_cache >= -1.0,
             "vote_cache should be >= -1.0, got #{obs.vote_cache}")
      assert(obs.vote_cache < 0.0,
             "vote_cache should be < 0.0, got #{obs.vote_cache}")
    end

    # "No Opinion" (0.0) should match exactly 0.0
    no_opinion_results = Observation.confidence(0.0)
    no_opinion_results.each do |obs|
      assert_equal(0.0, obs.vote_cache, "vote_cache should be exactly 0.0")
    end

    # "I'd Call It That" (3.0) should match vote_cache > 2.0 AND <= 3.0
    max_results = Observation.confidence(3.0)
    max_results.each do |obs|
      assert(obs.vote_cache > 2.0,
             "vote_cache should be > 2.0, got #{obs.vote_cache}")
      assert(obs.vote_cache <= 3.0,
             "vote_cache should be <= 3.0, got #{obs.vote_cache}")
    end

    # "As If!" (-3.0) should match vote_cache >= -3.0 AND < -2.0
    min_results = Observation.confidence(-3.0)
    min_results.each do |obs|
      assert(obs.vote_cache >= -3.0,
             "vote_cache should be >= -3.0, got #{obs.vote_cache}")
      assert(obs.vote_cache < -2.0,
             "vote_cache should be < -2.0, got #{obs.vote_cache}")
    end
  end

  def test_scope_confidence_range_searches
    # Range searches should combine lower bound from min with upper bound
    # from max

    # "Promising" (2.0) to "I'd Call It That" (3.0)
    # Should search for vote_cache > 1.0 AND <= 3.0
    promising_to_max = Observation.confidence(2.0, 3.0)
    promising_to_max.each do |obs|
      assert(obs.vote_cache > 1.0,
             "vote_cache should be > 1.0, got #{obs.vote_cache}")
      assert(obs.vote_cache <= 3.0,
             "vote_cache should be <= 3.0, got #{obs.vote_cache}")
    end

    # "Could Be" (1.0) to "Promising" (2.0)
    # Should search for vote_cache > 0.0 AND <= 2.0
    could_be_to_promising = Observation.confidence(1.0, 2.0)
    could_be_to_promising.each do |obs|
      assert(obs.vote_cache > 0.0,
             "vote_cache should be > 0.0, got #{obs.vote_cache}")
      assert(obs.vote_cache <= 2.0,
             "vote_cache should be <= 2.0, got #{obs.vote_cache}")
    end

    # "Not Likely" (-2.0) to "Promising" (2.0)
    # Should search for vote_cache >= -2.0 AND <= 2.0
    not_likely_to_promising = Observation.confidence(-2.0, 2.0)
    not_likely_to_promising.each do |obs|
      assert(obs.vote_cache >= -2.0,
             "vote_cache should be >= -2.0, got #{obs.vote_cache}")
      assert(obs.vote_cache <= 2.0,
             "vote_cache should be <= 2.0, got #{obs.vote_cache}")
    end

    # "Not Likely" (-2.0) to "Doubtful" (-1.0)
    # Should search for vote_cache >= -2.0 AND < 0.0
    not_likely_to_doubtful = Observation.confidence(-2.0, -1.0)
    not_likely_to_doubtful.each do |obs|
      assert(obs.vote_cache >= -2.0,
             "vote_cache should be >= -2.0, got #{obs.vote_cache}")
      assert(obs.vote_cache < 0.0,
             "vote_cache should be < 0.0, got #{obs.vote_cache}")
    end
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

    obs = observations(:imported_inat_obs)
    assert_equal("mo_inat_import", obs.source)
    assert_equal(:source_credit_mo_inat_import, obs.source_credit)
  end

  def test_hidden_location
    create_new_objects
    assert_false(@cc_obs.gps_hidden)
    @cc_obs.location = locations(:loc_hidden)
    @cc_obs.save
    @cc_obs.reload
    assert(@cc_obs.gps_hidden)
  end
end
