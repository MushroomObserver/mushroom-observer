require File.dirname(__FILE__) + '/../test_helper'

class QueuedEmailTest < Test::Unit::TestCase
  fixtures :users
  fixtures :comments
  fixtures :observations
  fixtures :namings
  fixtures :names
  fixtures :past_names
  fixtures :notifications

  def test_comment_email
    QueuedEmail.queue_emails(true)
    CommentEmail.find_or_create_email(@rolf, @mary, @minimal_comment)
    assert_email(0, {
      :flavor => :comment,
      :from => @rolf,
      :to => @mary,
      :comment => @minimal_comment.id
    })
    email = QueuedEmail.find(:first).deliver_email
    assert(email)
    assert_equal(:comment, email.flavor)
    assert_equal(@rolf, email.user)
    assert_equal(@mary, email.to_user)
    assert_equal(@minimal_comment, email.comment)
  end

  def test_consensus_change_email
    QueuedEmail.queue_emails(true)
    ConsensusChangeEmail.create_email(@rolf, @mary, @coprinus_comatus_obs, @agaricus_campestris, @coprinus_comatus)
    assert_email(0, {
      :flavor => :consensus_change,
      :from => @rolf,
      :to => @mary,
      :observation => @coprinus_comatus_obs.id,
      :old_name => @agaricus_campestris.id,
      :new_name => @coprinus_comatus.id
    })
    email = QueuedEmail.find(:first).deliver_email
    assert(email)
    assert_equal(:consensus_change, email.flavor)
    assert_equal(@rolf, email.user)
    assert_equal(@mary, email.to_user)
    assert_equal(@coprinus_comatus_obs, email.observation)
    assert_equal(@agaricus_campestris, email.old_name)
    assert_equal(@coprinus_comatus, email.new_name)
  end

  def test_feature_email
    QueuedEmail.queue_emails(true)
    FeatureEmail.create_email(@mary, 'blah blah blah')
    assert_email(0, {
      :flavor => :feature,
      :to => @mary,
      :note => 'blah blah blah',
    })
    email = QueuedEmail.find(:first).deliver_email
    assert(email)
    assert_equal(:feature, email.flavor)
    assert_equal(nil, email.user)
    assert_equal(@mary, email.to_user)
  end

  def test_name_change_email
    QueuedEmail.queue_emails(true)
    NameChangeEmail.create_email(@rolf, @mary, @peltigera, true)
    assert_email(0, {
      :flavor => :name_change,
      :from => @rolf,
      :to => @mary,
      :name => @peltigera.id,
      :old_version => @peltigera.version,
      :new_version => @peltigera.version,
      :review_status => @peltigera.review_status.to_s,
    })
    email = QueuedEmail.find(:first).deliver_email
    assert(email)
    assert_equal(:name_change, email.flavor)
    assert_equal(@rolf, email.user)
    assert_equal(@mary, email.to_user)
    assert_equal(@peltigera, email.name)
    assert_equal(@peltigera.version, email.old_version)
    assert_equal(@peltigera.version, email.new_version)
    assert_equal(@peltigera.review_status, email.review_status)
  end

  def test_name_proposal_email
    QueuedEmail.queue_emails(true)
    NameProposalEmail.create_email(@rolf, @mary, @coprinus_comatus_obs, @coprinus_comatus_naming)
    assert_email(0, {
      :flavor => :name_proposal,
      :from => @rolf,
      :to => @mary,
      :naming => @coprinus_comatus_naming.id,
      :observation => @coprinus_comatus_obs.id,
    })
    email = QueuedEmail.find(:first).deliver_email
    assert(email)
    assert_equal(:name_proposal, email.flavor)
    assert_equal(@rolf, email.user)
    assert_equal(@mary, email.to_user)
    assert_equal(@coprinus_comatus_naming, email.naming)
    assert_equal(@coprinus_comatus_obs, email.observation)
  end

  def test_naming_email
    QueuedEmail.queue_emails(true)
    NamingEmail.create_email(@agaricus_campestris_notification_with_note, @agaricus_campestris_naming)
    assert_email(0, {
      :flavor => :naming,
      :from => @mary,
      :to => @rolf,
      :naming => @agaricus_campestris_naming.id,
      :notification => @agaricus_campestris_notification_with_note.id,
    })
    email = QueuedEmail.find(:first).deliver_email
    assert(email)
    assert_equal(:naming, email.flavor)
    assert_equal(@mary, email.user)
    assert_equal(@rolf, email.to_user)
  end

  def test_publish_email
    QueuedEmail.queue_emails(true)
    PublishEmail.create_email(@rolf, @mary, @peltigera)
    assert_email(0, {
      :flavor => :publish,
      :from => @rolf,
      :to => @mary,
      :name => @peltigera.id,
    })
    email = QueuedEmail.find(:first).deliver_email
    assert(email)
    assert_equal(:publish, email.flavor)
    assert_equal(@rolf, email.user)
    assert_equal(@mary, email.to_user)
  end
end
