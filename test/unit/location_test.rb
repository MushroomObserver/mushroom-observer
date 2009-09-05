require File.dirname(__FILE__) + '/../test_helper'

class LocationTest < Test::Unit::TestCase
  fixtures :locations
  fixtures :past_locations
  fixtures :users

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_email_notification
    QueuedEmail.queue_emails(true)
    emails = QueuedEmail.find(:all).length
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
    # Rolf changes notes: notify Dick (all); Rolf becomes editor.
    @albion.notes = ''
    @albion.save_if_changed(@rolf) and @albion.add_editor(@rolf)
    assert_equal(version + 1, @albion.version)
    assert_equal(0, @albion.authors.length)
    assert_equal(1, @albion.editors.length)
    assert_equal(@rolf, @albion.editors.first)
    assert_equal(emails + 1, QueuedEmail.find(:all).length)
    assert_email(emails, {
        :flavor      => :location_change,
        :from        => @rolf,
        :to          => @dick,
        :location    => @albion.id,
        :old_version => @albion.version-1,
        :new_version => @albion.version,
    })

    # Dick wisely reconsiders getting emails for every location change.
    # Have Mary opt in for all temporarily just to make sure she doesn't
    # send herself emails when she changes things.
    @dick.email_locations_all = false
    @dick.save
    @mary.email_locations_all = true
    @mary.save

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       x       .       x       .
    # 3 Dick:       x       .       .       .
    # Authors: --   editors: Rolf
    # Mary writes notes: no emails; Mary becomes author.
    @albion.notes = "Mary wrote this."
    @albion.save_if_changed(@mary) and @albion.add_editor(@mary)
    assert_equal(version + 2, @albion.version)
    assert_equal(1, @albion.authors.length)
    assert_equal(1, @albion.editors.length)
    assert_equal(@mary, @albion.authors.first)
    assert_equal(@rolf, @albion.editors.first)
    assert_equal(emails + 1, QueuedEmail.find(:all).length)

    # Have Mary opt back out.
    @mary.email_locations_all = false
    @mary.save

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       x       .       .       .
    # 3 Dick:       x       .       .       .
    # Authors: Mary   editors: Rolf
    # Now when Rolf changes the notes Mary should get notified.
    @albion.notes = "Rolf changed it to this."
    @albion.save_if_changed(@rolf) and @albion.add_editor(@rolf)
    assert_equal(1, @albion.authors.length)
    assert_equal(1, @albion.editors.length)
    assert_equal(@mary, @albion.authors.first)
    assert_equal(@rolf, @albion.editors.first)
    assert_equal(version + 3, @albion.version)
    assert_equal(emails + 2, QueuedEmail.find(:all).length)
    assert_email(emails + 1, {
        :flavor      => :location_change,
        :from        => @rolf,
        :to          => @mary,
        :location    => @albion.id,
        :old_version => @albion.version-1,
        :new_version => @albion.version,
    })

    # Have Mary opt out of author-notifications to make sure that's why she
    # got the last email.
    @albion.authors.first.email_locations_author = false

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       .       .       .       .
    # 3 Dick:       x       .       .       .
    # Authors: Mary   editors: Rolf
    # Have Dick change it to make sure rolf doesn't get an email as he is just
    # an editor and he has opted out of such notifications.
    @albion.notes = "Dick changed it now."
    @albion.save_if_changed(@dick) and @albion.add_editor(@dick)
    assert_equal(version + 4, @albion.version)
    assert_equal(1, @albion.authors.length)
    assert_equal(2, @albion.editors.length)
    assert_equal(@mary, @albion.authors.first)
    assert_equal([@rolf.id, @dick.id], @albion.editors.map(&:id).sort)
    assert_equal(emails + 2, QueuedEmail.find(:all).length)

    # Have everyone request editor-notifications and have Dick change it again.
    # Only Rolf should get notified since Mary is an author, not an editor, and
    # Dick shouldn't send himself notifications.
    @albion.authors.first.email_locations_editor = true  # (Mary)
    @albion.editors.first.email_locations_editor = true  # (Rolf)
    @albion.editors.last.email_locations_editor  = true  # (Dick)
    @dick.save

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       x       .       .
    # 2 Mary:       .       x       .       .
    # 3 Dick:       x       x       .       .
    # Authors: Mary   editors: Rolf, Dick
    @albion.notes = "Dick changed it again."
    @albion.save_if_changed(@dick) and @albion.add_editor(@dick)
    assert_equal(version + 5, @albion.version)
    assert_equal(1, @albion.authors.length)
    assert_equal(2, @albion.editors.length)
    assert_equal(@mary, @albion.authors.first)
    assert_equal([@rolf.id, @dick.id], @albion.editors.map(&:id).sort)
    assert_equal(emails + 3, QueuedEmail.find(:all).length)
    assert_email(emails + 2, {
        :flavor      => :location_change,
        :from        => @dick,
        :to          => @rolf,
        :location    => @albion.id,
        :old_version => @albion.version-1,
        :new_version => @albion.version,
    })

    # Have Mary and Dick express interest, Rolf express disinterest, 
    # then have Dick change it again.  Mary should get an email.
    Interest.new(:object => @albion, :user => @rolf, :state => false).save
    Interest.new(:object => @albion, :user => @mary, :state => true).save
    Interest.new(:object => @albion, :user => @dick, :state => true).save

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       x       .       no
    # 2 Mary:       .       x       .       yes
    # 3 Dick:       x       x       .       yes
    # Authors: Mary   editors: Rolf, Dick
    @albion.notes = "Dick changed it yet again."
    @albion.save_if_changed(@dick) and @albion.add_editor(@dick)
    assert_equal(version + 6, @albion.version)
    assert_equal(1, @albion.authors.length)
    assert_equal(2, @albion.editors.length)
    assert_equal(@mary, @albion.authors.first)
    assert_equal([@rolf.id, @dick.id], @albion.editors.map(&:id).sort)
    assert_equal(emails + 4, QueuedEmail.find(:all).length)
    assert_email(emails + 3, {
        :flavor        => :location_change,
        :from          => @dick,
        :to            => @mary,
        :location      => @albion.id,
        :old_version   => @albion.version-1,
        :new_version   => @albion.version,
    })
  end
end
