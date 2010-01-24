require File.dirname(__FILE__) + '/../boot'

class LocationTest < Test::Unit::TestCase
  fixtures :locations
  fixtures :past_locations
  fixtures :users

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_email_notification
    QueuedEmail.queue_emails(true)
    QueuedEmail.all.map(&:destroy)
    version = @albion.version

    @rolf.email_locations_author = true
    @rolf.email_locations_editor = false
    @rolf.email_locations_all    = false
    @rolf.save

    @mary.email_locations_author = true
    @mary.email_locations_editor = false
    @mary.email_locations_all    = false
    @mary.save

    @dick.email_locations_author = true
    @dick.email_locations_editor = false
    @dick.email_locations_all    = true
    @dick.save

    assert_equal(0, @albion.authors.length)
    assert_equal(0, @albion.editors.length)

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       x       .       .       .
    # 3 Dick:       x       .       x       .
    # Authors: --   editors: --
    # Rolf changes notes: notify Dick (all); Rolf becomes author.
    User.current = @rolf
    @albion.reload
    @albion.notes = ''
    @albion.save
    assert_equal(version + 1, @albion.version)
    assert_equal(1, @albion.authors.length)
    assert_equal(0, @albion.editors.length)
    assert_equal(@rolf, @albion.authors.first)
    assert_equal(1, QueuedEmail.all.length)
    assert_email(0,
      :flavor      => 'QueuedEmail::LocationChange',
      :from        => @rolf,
      :to          => @dick,
      :location    => @albion.id,
      :old_version => @albion.version-1,
      :new_version => @albion.version
    )

    # Dick wisely reconsiders getting emails for every location change.
    # Have Mary opt in for all temporarily just to make sure she doesn't
    # send herself emails when she changes things.
    @dick.email_locations_all = false
    @dick.save
    @mary.email_locations_all = true
    @mary.save

    # Demote Rolf, because he wasn't supposed to become author yet.
    # (We've changed criteria for authorship so that Rolf was able to
    # become author even though he hadn't written anything.)
    @albion.remove_author(@rolf)
    assert_equal(0, @albion.authors.length)
    assert_equal(1, @albion.editors.length)
    assert_equal(@rolf, @albion.editors.first)

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       x       .       x       .
    # 3 Dick:       x       .       .       .
    # Authors: --   editors: Rolf
    # Mary writes notes: no emails; Mary becomes author.
    User.current = @mary
    @albion.reload
    @albion.notes = "Mary wrote this."
    @albion.save
    assert_equal(version + 2, @albion.version)
    assert_equal(1, @albion.authors.length)
    assert_equal(1, @albion.editors.length)
    assert_equal(@mary, @albion.authors.first)
    assert_equal(@rolf, @albion.editors.first)
    assert_equal(1, QueuedEmail.all.length)

    # Have Mary opt back out.
    @mary.email_locations_all = false
    @mary.save

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       x       .       .       .
    # 3 Dick:       x       .       .       .
    # Authors: Mary   editors: Rolf
    # Now when Rolf changes the notes Mary should get notified.
    User.current = @rolf
    @albion.reload
    @albion.notes = "Rolf changed it to this."
    @albion.save
    assert_equal(1, @albion.authors.length)
    assert_equal(1, @albion.editors.length)
    assert_equal(@mary, @albion.authors.first)
    assert_equal(@rolf, @albion.editors.first)
    assert_equal(version + 3, @albion.version)
    assert_equal(2, QueuedEmail.all.length)
    assert_email(1,
      :flavor      => 'QueuedEmail::LocationChange',
      :from        => @rolf,
      :to          => @mary,
      :location    => @albion.id,
      :old_version => @albion.version-1,
      :new_version => @albion.version
    )

    # Have Mary opt out of author-notifications to make sure that's why she
    # got the last email.
    @mary.email_locations_author = false
    @mary.save

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       .       .       .       .
    # 3 Dick:       x       .       .       .
    # Authors: Mary   editors: Rolf
    # Have Dick change it to make sure rolf doesn't get an email as he is just
    # an editor and he has opted out of such notifications.
    User.current = @dick
    @albion.reload
    @albion.notes = "Dick changed it now."
    @albion.save
    assert_equal(version + 4, @albion.version)
    assert_equal(1, @albion.authors.length)
    assert_equal(2, @albion.editors.length)
    assert_equal(@mary, @albion.authors.first)
    assert_equal([@rolf.id, @dick.id], @albion.editors.map(&:id).sort)
    assert_equal(2, QueuedEmail.all.length)

    # Have everyone request editor-notifications and have Dick change it again.
    # Only Rolf should get notified since Mary is an author, not an editor, and
    # Dick shouldn't send himself notifications.
    @mary.email_locations_editor = true
    @mary.save
    @rolf.email_locations_editor = true
    @rolf.save
    @dick.email_locations_editor = true
    @dick.save

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       x       .       .
    # 2 Mary:       .       x       .       .
    # 3 Dick:       x       x       .       .
    # Authors: Mary   editors: Rolf, Dick
    User.current = @dick
    @albion.reload
    @albion.notes = "Dick changed it again."
    @albion.save
    assert_equal(version + 5, @albion.version)
    assert_equal(1, @albion.authors.length)
    assert_equal(2, @albion.editors.length)
    assert_equal(@mary, @albion.authors.first)
    assert_equal([@rolf.id, @dick.id], @albion.editors.map(&:id).sort)
    assert_equal(3, QueuedEmail.all.length)
    assert_email(2,
      :flavor      => 'QueuedEmail::LocationChange',
      :from        => @dick,
      :to          => @rolf,
      :location    => @albion.id,
      :old_version => @albion.version-1,
      :new_version => @albion.version
    )

    # Have Mary and Dick express interest, Rolf express disinterest, 
    # then have Dick change it again.  Mary should get an email.
    Interest.create(:object => @albion, :user => @rolf, :state => false)
    Interest.create(:object => @albion, :user => @mary, :state => true)
    Interest.create(:object => @albion, :user => @dick, :state => true)

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       x       .       no
    # 2 Mary:       .       x       .       yes
    # 3 Dick:       x       x       .       yes
    # Authors: Mary   editors: Rolf, Dick
    User.current = @dick
    @albion.reload
    @albion.notes = "Dick changed it yet again."
    @albion.save
    assert_equal(version + 6, @albion.version)
    assert_equal(1, @albion.authors.length)
    assert_equal(2, @albion.editors.length)
    assert_equal(@mary, @albion.authors.first)
    assert_equal([@rolf.id, @dick.id], @albion.editors.map(&:id).sort)
    assert_equal(4, QueuedEmail.all.length)
    assert_email(3,
      :flavor        => 'QueuedEmail::LocationChange',
      :from          => @dick,
      :to            => @mary,
      :location      => @albion.id,
      :old_version   => @albion.version-1,
      :new_version   => @albion.version
    )
  end
end
