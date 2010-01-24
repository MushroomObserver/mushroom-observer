require File.dirname(__FILE__) + '/../boot'

class ObservationTest < Test::Unit::TestCase
  fixtures :observations
  fixtures :users
  fixtures :names
  fixtures :namings
  fixtures :images
  fixtures :images_observations
  fixtures :votes

  def setup
    @cc_obs = Observation.new
    @cc_obs.user = @mary
    @cc_obs.when = Time.now
    @cc_obs.where = "Glendale, California"
    @cc_obs.notes = "New"
    @cc_obs.name = @fungi
    @cc_nam = Naming.new
    @cc_nam.user = @mary
    @cc_nam.name = @fungi
    @cc_nam.observation = @cc_obs
  end

################################################################################

  # Add an observation to the database
  def test_create
    assert_kind_of Observation, observations(:minimal_unknown)
    assert_kind_of Observation, @cc_obs
    assert_kind_of Naming, namings(:minimal_unknown_naming)
    assert_kind_of Naming, @cc_nam
    assert @cc_obs.save, @cc_obs.errors.full_messages.join("; ")
    assert @cc_nam.save, @cc_nam.errors.full_messages.join("; ")
  end

  def test_update
    @cc_nam.save
    assert_equal @fungi, @cc_nam.name
    @cc_nam.name = @coprinus_comatus
    assert @cc_nam.save, @cc_nam.errors.full_messages.join("; ")
    @cc_nam.reload
    assert_equal @coprinus_comatus.search_name, @cc_nam.text_name
  end

  # Test setting a name using a string
  def test_validate
    @cc_obs.user = nil
    @cc_obs.when = nil
    @cc_obs.where = nil
    assert !@cc_obs.save
    assert_equal 3, @cc_obs.errors.count
    assert_equal :validate_observation_user_missing.t, @cc_obs.errors.on(:user)
    assert_equal :validate_observation_when_missing.t, @cc_obs.errors.on(:when)
    assert_equal :validate_observation_where_missing.t, @cc_obs.errors.on(:where)
  end

  def test_destroy
    User.current = @rolf
    @cc_obs.save
    @cc_nam.save
    @cc_obs.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Observation.find(@cc_obs.id) }
    assert_raise(ActiveRecord::RecordNotFound) { Naming.find(@cc_nam.id) }
  end

  def test_all_observations_order
    obs = Observation.find(:all, :order => "id")
    assert_equal @coprinus_comatus_obs.id, obs[2].id
    assert_equal @detailed_unknown.id, obs[1].id
  end

  def test_remove_image_by_id_twice
    @minimal_unknown.images = [
      @commercial_inquiry_image,
      @disconnected_coprinus_comatus_image,
      @connected_coprinus_comatus_image
    ]
    @minimal_unknown.thumb_image = @commercial_inquiry_image
    @minimal_unknown.remove_image_by_id(@commercial_inquiry_image.id)
    assert_equal(@minimal_unknown.thumb_image, @disconnected_coprinus_comatus_image)
    @minimal_unknown.remove_image_by_id(@disconnected_coprinus_comatus_image.id)
    assert_equal(@minimal_unknown.thumb_image, @connected_coprinus_comatus_image)
  end

  def test_name_been_proposed
    assert(@coprinus_comatus_obs.name_been_proposed?(@coprinus_comatus))
    assert(@coprinus_comatus_obs.name_been_proposed?(@agaricus_campestris))
    assert(!@coprinus_comatus_obs.name_been_proposed?(@conocybe_filaris))
  end

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_email_notification_1
    # There might be notifications left-over from other tests.
    Notification.all.map(&:destroy)
    Interest.all.map(&:destroy)

    QueuedEmail.queue_emails(true)
    QueuedEmail.all.map(&:destroy)

    # Make sure Rolf has requested emails.
    @rolf.email_comments_owner = true
    @rolf.email_comments_response = true
    @rolf.email_observations_naming = true
    @rolf.email_observations_consensus = true
    @rolf.save

    # Make sure observation name starts as Coprinus comatus.
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)

    # Observation owner is not notified if comment added by themselves.
    # (Rolf owns @coprinus_comatus_obs, one naming, two votes, conf. around 1.5.)
    new_comment = Comment.create(
      :created => Time.now,
      :user    => @rolf,
      :summary => 'This is Rolf...',
      :object  => @coprinus_comatus_obs
    )
    assert_equal(0, QueuedEmail.all.length)

    # Observation owner is not notified if naming added by themselves.
    new_naming = Naming.create(
      :created     => Time.now,
      :modified    => Time.now,
      :observation => @coprinus_comatus_obs,
      :name        => @agaricus_campestris,
      :user        => @rolf,
      :vote_cache  => 0
    )
    assert_equal(0, QueuedEmail.all.length)
    @coprinus_comatus_obs.reload
    assert_equal(@coprinus_comatus, @coprinus_comatus_obs.name)

    # Observation owner is not notified if consensus changed by themselves.
    Vote.create(
      :created     => Time.now,
      :modified    => Time.now,
      :observation => @coprinus_comatus_obs,
      :naming      => new_naming,
      :user        => @rolf,
      :value       => 3
    )
    @coprinus_comatus_obs.calc_consensus(@rolf)
    @coprinus_comatus_obs.reload
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.name)
    assert_equal(0, QueuedEmail.all.length)

    # Make Rolf opt out of all emails.
    @rolf.email_comments_owner = false
    @rolf.email_comments_response = false
    @rolf.email_observations_naming = false
    @rolf.email_observations_consensus = false
    @rolf.save

    # Rolf should not be notified of anything here, either...
    new_comment = Comment.create(
      :created => Time.now,
      :user    => @dick,
      :summary => 'This is Dick...',
      :object  => @coprinus_comatus_obs
    )
    assert_equal(0, QueuedEmail.all.length)

    new_naming = Naming.create(
      :created     => Time.now,
      :modified    => Time.now,
      :observation => @coprinus_comatus_obs,
      :name        => @peltigera,
      :user        => @dick,
      :vote_cache  => 0
    )
    assert_equal(0, QueuedEmail.all.length)
    @coprinus_comatus_obs.reload
    assert_equal(@agaricus_campestris, @coprinus_comatus_obs.name)

    # Make sure this changes consensus...
    @dick.contribution = 100000000000
    @dick.save
    Vote.create(
      :created     => Time.now,
      :modified    => Time.now,
      :observation => @coprinus_comatus_obs,
      :naming      => new_naming,
      :user        => @dick,
      :value       => 3
    )
    @coprinus_comatus_obs.calc_consensus(@dick)
    @coprinus_comatus_obs.reload
    assert_equal(@peltigera, @coprinus_comatus_obs.name)
    assert_equal(0, QueuedEmail.all.length)
  end

  def test_email_notification_2
    # There might be notifications left-over from other tests.
    Notification.all.map(&:destroy)
    Interest.all.map(&:destroy)

    QueuedEmail.queue_emails(true)
    QueuedEmail.all.map(&:destroy)

    # Make sure Rolf has requested no emails (will turn on one at a time to be
    # sure the right pref affects the right notification).
    @rolf.email_comments_owner = false
    @rolf.email_comments_response = false
    @rolf.email_observations_naming = false
    @rolf.email_observations_consensus = false
    @rolf.save

    # Observation owner is notified if comment added by someone else.
    # (Rolf owns @coprinus_comatus_obs, one naming, two votes, conf. around 1.5.)
    @rolf.email_comments_owner = true
    @rolf.save
    new_comment = Comment.create(
      :created => Time.now,
      :user    => @mary,
      :summary => 'This is Mary...',
      :object  => @coprinus_comatus_obs
    )
    assert_equal(1, QueuedEmail.all.length)
    assert_email(0,
      :flavor  => 'QueuedEmail::Comment',
      :from    => @mary,
      :to      => @rolf,
      :comment => new_comment.id
    )

    # Observation owner is notified if naming added by someone else.
    @rolf.email_comments_owner = false
    @rolf.email_observations_naming = true
    @rolf.save
    @coprinus_comatus_obs.user.reload
    new_naming = Naming.create(
      :created     => Time.now,
      :modified    => Time.now,
      :observation => @coprinus_comatus_obs,
      :name        => @agaricus_campestris,
      :user        => @mary,
      :vote_cache  => 0
    )
    assert_equal(2, QueuedEmail.all.length)
    assert_email(1,
      :flavor      => 'QueuedEmail::NameProposal',
      :from        => @mary,
      :to          => @rolf,
      :observation => @coprinus_comatus_obs.id,
      :naming      => new_naming.id
    )

    # Observation owner is notified if consensus changed by someone else.
    @rolf.email_observations_naming = false
    @rolf.email_observations_consensus = true
    @rolf.save
    # (Actually, Mary already gave this her highest possible vote,
    # so think of this as Mary changing Rolf's vote. :)
    @coprinus_comatus_other_naming_rolf_vote.value = 3
    @coprinus_comatus_other_naming_rolf_vote.save
    @coprinus_comatus_obs.calc_consensus(@mary)
    assert_equal(3, QueuedEmail.all.length)
    assert_email(2,
      :flavor      => 'QueuedEmail::ConsensusChange',
      :from        => @mary,
      :to          => @rolf,
      :observation => @coprinus_comatus_obs.id,
      :old_name    => @coprinus_comatus.id,
      :new_name    => @agaricus_campestris.id
    )

    # Make sure Mary gets notified if Rolf responds to her comment.
    @mary.email_comments_response = true
    @mary.save
    new_comment = Comment.create(
      :created => Time.now,
      :user    => @rolf,
      :summary => 'This is Rolf...',
      :object  => @coprinus_comatus_obs
    )
    assert_equal(4, QueuedEmail.all.length)
    assert_email(3,
      :flavor  => 'QueuedEmail::Comment',
      :from    => @rolf,
      :to      => @mary,
      :comment => new_comment.id
    )
  end

  def test_email_notification_3
    # There might be objects left-over from other tests.
    Notification.all.map(&:destroy)
    Interest.all.map(&:destroy)

    QueuedEmail.queue_emails(true)
    QueuedEmail.all.map(&:destroy)

    # Make sure Rolf has requested emails.
    @rolf.email_comments_owner = true
    @rolf.email_comments_response = true
    @rolf.email_observations_naming = true
    @rolf.email_observations_consensus = true
    @rolf.save

    # Make sure Dick has requested no emails.
    @dick.email_comments_owner = false
    @dick.email_comments_response = false
    @dick.email_observations_naming = false
    @dick.email_observations_consensus = false
    @dick.save

    # Make Rolf ignore his own observation (will override prefs).
    Interest.create(
      :object => @coprinus_comatus_obs,
      :user   => @rolf,
      :state  => false
    )

    # But make Dick watch it (will override prefs).
    Interest.create(
      :object => @coprinus_comatus_obs,
      :user   => @dick,
      :state  => true
    )

    # Watcher is notified if comment added.
    # (Rolf owns @coprinus_comatus_obs, one naming, two votes, conf. around 1.5.)
    (new_comment = Comment.new(
      :created => Time.now,
      :user    => @mary,
      :summary => 'This is Mary...',
      :object  => @coprinus_comatus_obs
    )).save
    assert_equal(1, QueuedEmail.all.length)
    assert_email(0,
      :flavor  => 'QueuedEmail::Comment',
      :from    => @mary,
      :to      => @dick,
      :comment => new_comment.id
    )

    # Watcher is notified if naming added.
    (new_naming = Naming.new(
      :created     => Time.now,
      :modified    => Time.now,
      :observation => @coprinus_comatus_obs,
      :name        => @agaricus_campestris,
      :user        => @mary,
      :vote_cache  => 0
    )).save
    assert_equal(2, QueuedEmail.all.length)
    assert_email(1,
      :flavor      => 'QueuedEmail::NameProposal',
      :from        => @mary,
      :to          => @dick,
      :observation => @coprinus_comatus_obs.id,
      :naming      => new_naming.id
    )

    # Watcher is notified if consensus changed.
    # (Actually, Mary already gave this her highest possible vote,
    # so think of this as Mary changing Rolf's vote. :)
    @coprinus_comatus_other_naming_rolf_vote.value = 3
    @coprinus_comatus_other_naming_rolf_vote.save
    @coprinus_comatus_obs.calc_consensus(@mary)
    assert_equal(3, QueuedEmail.all.length)
    assert_email(2,
       :flavor      => 'QueuedEmail::ConsensusChange',
       :from        => @mary,
       :to          => @dick,
       :observation => @coprinus_comatus_obs.id,
       :old_name    => @coprinus_comatus.id,
       :new_name    => @agaricus_campestris.id
    )

    # Watcher is also notified of changes in the observation.
    @coprinus_comatus_obs.notes = 'I have new information on this observation.'
    @coprinus_comatus_obs.save
    assert_equal(4, QueuedEmail.all.length)

    # Make sure subsequent changes update existing email.
    @coprinus_comatus_obs.where = 'Somewhere else'
    @coprinus_comatus_obs.save
    assert_equal(4, QueuedEmail.all.length)

    # Same deal with adding and removing images.
    @coprinus_comatus_obs.add_image_by_id(@disconnected_coprinus_comatus_image.id)
    assert_equal(4, QueuedEmail.all.length)
    @coprinus_comatus_obs.remove_image_by_id(@disconnected_coprinus_comatus_image.id)
    assert_equal(4, QueuedEmail.all.length)
    assert_email(3,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @dick,
      :observation => @coprinus_comatus_obs.id,
      :note        => 'notes,location,thumb_image_id,added_image,removed_image'
    )
  end

  def test_email_notification_4
    # There might be notifications left-over from other tests.
    Notification.all.map(&:destroy)
    Interest.all.map(&:destroy)

    QueuedEmail.queue_emails(true)
    QueuedEmail.all.map(&:destroy)

    marys_interest = Interest.create(
      :object => @coprinus_comatus_obs,
      :user   => @mary,
      :state  => false
    )

    dicks_interest = Interest.create(
      :object => @coprinus_comatus_obs,
      :user   => @dick,
      :state  => false
    )

    katrinas_interest = Interest.create(
      :object => @coprinus_comatus_obs,
      :user   => @katrina,
      :state  => false
    )

    # Make change to observation.
    marys_interest.state = true
    marys_interest.save
    @coprinus_comatus_obs.notes = 'I have new information on this observation.'
    @coprinus_comatus_obs.save
    assert_equal(1, QueuedEmail.all.length)
    assert_email(0,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @mary,
      :observation => @coprinus_comatus_obs.id,
      :note        => 'notes'
    )

    # Add image to observation.
    marys_interest.state = false
    marys_interest.save
    dicks_interest.state = true
    dicks_interest.save
    @coprinus_comatus_obs.reload
    @coprinus_comatus_obs.add_image_by_id(@disconnected_coprinus_comatus_image.id)
    assert_equal(2, QueuedEmail.all.length)
    assert_email(1,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @dick,
      :observation => @coprinus_comatus_obs.id,
      :note        => 'thumb_image_id,added_image'
    )

    # Destroy observation.
    dicks_interest.state = false
    dicks_interest.save
    katrinas_interest.state = true
    katrinas_interest.save
    User.current = @rolf
    @coprinus_comatus_obs.reload
    @coprinus_comatus_obs.destroy
    katrinas_interest.state = false
    katrinas_interest.save
    assert_equal(3, QueuedEmail.all.length)
    assert_email(2,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @katrina,
      :observation => 0,
      :note        => '**__Coprinus comatus__** (O.F. Müll.) Pers. (3)'
    )
  end
end
