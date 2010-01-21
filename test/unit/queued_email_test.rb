require File.dirname(__FILE__) + '/../test_helper'

class QueuedEmailTest < Test::Unit::TestCase
  fixtures :users
  fixtures :comments
  fixtures :observations
  fixtures :namings
  fixtures :names
  fixtures :past_names
  fixtures :locations
  fixtures :past_locations
  fixtures :notifications

  def teardown
    clear_unused_fixtures
    User.current = nil
  end

  def test_comment_email
    QueuedEmail::Comment.find_or_create_email(@rolf, @mary, @minimal_comment)
    assert_email(0,
      :flavor  => 'QueuedEmail::Comment',
      :from    => @rolf,
      :to      => @mary,
      :comment => @minimal_comment.id
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_consensus_change_email
    QueuedEmail::ConsensusChange.create_email(@rolf, @mary, @coprinus_comatus_obs, @agaricus_campestris, @coprinus_comatus)
    assert_email(0,
      :flavor      => 'QueuedEmail::ConsensusChange',
      :from        => @rolf,
      :to          => @mary,
      :observation => @coprinus_comatus_obs.id,
      :old_name    => @agaricus_campestris.id,
      :new_name    => @coprinus_comatus.id
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_feature_email
    QueuedEmail::Feature.create_email(@mary, 'blah blah blah')
    assert_email(0,
      :flavor => 'QueuedEmail::Feature',
      :to     => @mary,
      :note   => 'blah blah blah'
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_location_change_email
    QueuedEmail::LocationChange.create_email(@rolf, @mary, @albion)
    assert_email(0,
      :flavor      => 'QueuedEmail::LocationChange',
      :from        => @rolf,
      :to          => @mary,
      :location    => @albion.id,
      :old_version => @albion.version,
      :new_version => @albion.version
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_name_change_email
    QueuedEmail::NameChange.create_email(@rolf, @mary, @peltigera, true)
    assert_email(0,
      :flavor        => 'QueuedEmail::NameChange',
      :from          => @rolf,
      :to            => @mary,
      :name          => @peltigera.id,
      :old_version   => @peltigera.version,
      :new_version   => @peltigera.version,
      :review_status => @peltigera.review_status.to_s
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_name_proposal_email
    QueuedEmail::NameProposal.create_email(@rolf, @mary, @coprinus_comatus_obs, @coprinus_comatus_naming)
    assert_email(0,
      :flavor      => 'QueuedEmail::NameProposal',
      :from        => @rolf,
      :to          => @mary,
      :naming      => @coprinus_comatus_naming.id,
      :observation => @coprinus_comatus_obs.id
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_naming_email
    QueuedEmail::Naming.create_email(@agaricus_campestris_notification_with_note, @agaricus_campestris_naming)
    assert_email(0,
      :flavor       => 'QueuedEmail::Naming',
      :from         => @mary,
      :to           => @rolf,
      :naming       => @agaricus_campestris_naming.id,
      :notification => @agaricus_campestris_notification_with_note.id
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_observation_change_email
    QueuedEmail::ObservationChange.change_observation(@rolf, @mary, @coprinus_comatus_obs)
    assert_email(0,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @mary,
      :observation => @coprinus_comatus_obs.id,
      :note        => ''
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_observation_destroy
    QueuedEmail::ObservationChange.destroy_observation(@rolf, @mary, @coprinus_comatus_obs)
    assert_email(0,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @mary,
      :observation => 0,
      :note        => @coprinus_comatus_obs.unique_format_name
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_observation_add_image_email
    QueuedEmail::ObservationChange.change_images(@rolf, @mary, @coprinus_comatus_obs, :added_image)
    assert_email(0,
      :flavor      => 'QueuedEmail::ObservationChange',
      :from        => @rolf,
      :to          => @mary,
      :observation => @coprinus_comatus_obs.id,
      :note        => 'added_image'
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end

  def test_publish_email
    QueuedEmail::Publish.create_email(@rolf, @mary, @peltigera)
    assert_email(0,
      :flavor => 'QueuedEmail::Publish',
      :from   => @rolf,
      :to     => @mary,
      :name   => @peltigera.id
    )
    email = QueuedEmail.first.deliver_email
    assert(email)
  end
end
