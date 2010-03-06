require File.dirname(__FILE__) + '/../boot'

class LocationTest < UnitTestCase

  def test_versioning
    User.current = @mary
    loc = Location.create!(
      :display_name => 'Anywhere',
      :north        => 60,
      :south        => 50,
      :east         => 40,
      :west         => 30
    )
    assert_equal(@mary.id, loc.user_id)
    assert_equal(@mary.id, loc.versions.last.user_id)

    User.current = @rolf
    loc.display_name = 'Anywhere, USA'
    loc.save
    assert_equal(@mary.id, loc.user_id)
    assert_equal(@rolf.id, loc.versions.last.user_id)
    assert_equal(@mary.id, loc.versions.first.user_id)

    User.current = @dick
    desc = LocationDescription.create!(
      :location => loc,
      :notes    => 'Something.'
    )
    assert_equal(@dick.id, desc.user_id)
    assert_equal(@dick.id, desc.versions.last.user_id)
    assert_equal(@mary.id, loc.user_id)
    assert_equal(@rolf.id, loc.versions.last.user_id)
    assert_equal(@mary.id, loc.versions.first.user_id)

    User.current = @rolf
    desc.notes = 'Something else.'
    desc.save
    assert_equal(@dick.id, desc.user_id)
    assert_equal(@rolf.id, desc.versions.last.user_id)
    assert_equal(@dick.id, desc.versions.first.user_id)
  end

  # --------------------------------------
  #  Test email notification heuristics.
  # --------------------------------------

  def test_email_notification
    loc  = locations(:albion)
    desc = location_descriptions(:albion_desc)

    QueuedEmail.queue_emails(true)
    QueuedEmail.all.map(&:destroy)
    location_version = loc.version
    description_version = desc.version

    desc.authors.clear
    desc.editors.clear
    desc.reload

    @rolf.email_locations_admin  = false
    @rolf.email_locations_author = true
    @rolf.email_locations_editor = false
    @rolf.email_locations_all    = false
    @rolf.save

    @mary.email_locations_admin  = false
    @mary.email_locations_author = true
    @mary.email_locations_editor = false
    @mary.email_locations_all    = false
    @mary.save

    @dick.email_locations_admin  = false
    @dick.email_locations_author = true
    @dick.email_locations_editor = false
    @dick.email_locations_all    = true
    @dick.save

    assert_equal(0, desc.authors.length)
    assert_equal(0, desc.editors.length)

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       .       .       .
    # 2 Mary:       x       .       .       .
    # 3 Dick:       x       .       x       .
    # Authors: --   editors: --
    # Rolf changes notes: notify Dick (all); Rolf becomes editor.
    User.current = @rolf
    desc.reload
    desc.notes = ''
    desc.save
    assert_equal(description_version + 1, desc.version)
    assert_equal(0, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_equal(@rolf, desc.editors.first)
    assert_equal(1, QueuedEmail.count)
    assert_email(0,
      :flavor      => 'QueuedEmail::LocationChange',
      :from        => @rolf,
      :to          => @dick,
      :location    => loc.id,
      :description => desc.id,
      :old_location_version => loc.version,
      :new_location_version => loc.version,
      :old_description_version => desc.version-1,
      :new_description_version => desc.version
    )

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
    User.current = @mary
    desc.reload
    desc.notes = "Mary wrote this."
    desc.save
    assert_equal(description_version + 2, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_equal(@mary, desc.authors.first)
    assert_equal(@rolf, desc.editors.first)
    assert_equal(1, QueuedEmail.count)

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
    desc.reload
    desc.notes = "Rolf changed it to this."
    desc.save
    assert_equal(1, desc.authors.length)
    assert_equal(1, desc.editors.length)
    assert_equal(@mary, desc.authors.first)
    assert_equal(@rolf, desc.editors.first)
    assert_equal(description_version + 3, desc.version)
    assert_equal(2, QueuedEmail.count)
    assert_email(1,
      :flavor      => 'QueuedEmail::LocationChange',
      :from        => @rolf,
      :to          => @mary,
      :location    => loc.id,
      :description => desc.id,
      :old_location_version => loc.version,
      :new_location_version => loc.version,
      :old_description_version => desc.version-1,
      :new_description_version => desc.version
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
    desc.reload
    desc.notes = "Dick changed it now."
    desc.save
    assert_equal(description_version + 4, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(@mary, desc.authors.first)
    assert_equal([@rolf.id, @dick.id], desc.editors.map(&:id).sort)
    assert_equal(2, QueuedEmail.count)

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
    desc.reload
    desc.notes = "Dick changed it again."
    desc.save
    assert_equal(description_version + 5, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(@mary, desc.authors.first)
    assert_user_list_equal([@rolf, @dick], desc.editors)
    assert_equal(3, QueuedEmail.count)
    assert_email(2,
      :flavor      => 'QueuedEmail::LocationChange',
      :from        => @dick,
      :to          => @rolf,
      :location    => loc.id,
      :description => desc.id,
      :old_location_version => loc.version,
      :new_location_version => loc.version,
      :old_description_version => desc.version-1,
      :new_description_version => desc.version
    )

    # Have Mary and Dick express interest, Rolf express disinterest, 
    # then have Dick change it again.  Mary should get an email.
    Interest.create(:object => loc, :user => @rolf, :state => false)
    Interest.create(:object => loc, :user => @mary, :state => true)
    Interest.create(:object => loc, :user => @dick, :state => true)

    # email types:  author  editor  all     interest
    # 1 Rolf:       x       x       .       no
    # 2 Mary:       .       x       .       yes
    # 3 Dick:       x       x       .       yes
    # Authors: Mary   editors: Rolf, Dick
    User.current = @dick
    loc.reload
    loc.display_name = "Another Name"
    loc.save
    assert_equal(location_version + 1, loc.version)
    assert_equal(description_version + 5, desc.version)
    assert_equal(1, desc.authors.length)
    assert_equal(2, desc.editors.length)
    assert_equal(@mary, desc.authors.first)
    assert_user_list_equal([@rolf, @dick], desc.editors)
    assert_email(3,
      :flavor        => 'QueuedEmail::LocationChange',
      :from          => @dick,
      :to            => @mary,
      :location      => loc.id,
      :description   => desc.id,
      :old_location_version => loc.version-1,
      :new_location_version => loc.version,
      :old_description_version => desc.version,
      :new_description_version => desc.version
    )
    assert_equal(4, QueuedEmail.count)
  end
end
