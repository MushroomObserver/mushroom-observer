require File.dirname(__FILE__) + '/../boot'

class AbstractModelTest < Test::Unit::TestCase

  # Make sure update_view_stats updated stuff correctly (and did nothing else).
  def assert_same_but_view_stats(old_attrs, new_attrs, msg='')
    for key in (old_attrs.keys + new_attrs.keys).map(&:to_s).uniq.sort
      old_val = old_attrs[key] #|| old_attrs[key.to_sym]
      new_val = new_attrs[key] #|| new_attrs[key.to_sym]
      if key == 'num_views'
        assert_equal((old_val || 0) + 1, new_val, msg + "num_views wrong")
      elsif key == 'last_view'
        assert(new_val > 1.hour.ago, msg + "last_view more than one hour old")
        if old_val
          assert(new_val > old_val, msg + "last_view wasn't updated")
        end
      else
        assert_equal(old_val, new_val, msg + "#{key} shouldn't have changed!")
      end
    end
  end

  # Make sure authors and editors are as they should be.
  def assert_authors_and_editors(obj, authors, editors, msg)
    assert_equal(authors.sort, obj.authors.map(&:login).sort, 'Authors wrong: ' + msg)
    assert_equal(editors.sort, obj.editors.map(&:login).sort, 'Editors wrong: ' + msg)
  end

  # Make sure author/editor callbacks are updating contributions right.
  def assert_contributions(rolf, mary, dick, katrina, msg)
    for score, user in [
      [rolf, @rolf],
      [mary, @mary],
      [dick, @dick],
      [katrina, @katrina],
    ]
      assert_equal(10+score, user.reload.contribution,
                   "Contribution for #{user.login} wrong: " + msg)
    end
  end

################################################################################

  # -------------------------------------------------------------------
  #  Make sure ActiveRecord and database are getting timezones right.
  # -------------------------------------------------------------------

  def test_time_zone
    now = Time.now
    obs = Observation.create(
      :created => now,
      :when    => now,
      :where   => 'local'
    )

    # Make sure it fails to save if no user logged in.
    assert_equal(1, obs.errors.length, 'Should not have saved without login.')
    assert_equal(:validate_observation_user_missing.t, obs.dump_errors)

    # Log Rolf in ang try again.
    User.current = @rolf
    obs.save
    assert_equal(0, obs.errors.length, 'Could not save even when logged in.')

    # Make sure our local time is the same after being saved then retrieved
    # from database.  'Make sure the modified' timestamp also gets set to some
    # time between then and now.
    obs = Observation.last
    now1 = now.in_time_zone
    now2 = Time.now.in_time_zone
    assert_equal(now1.to_s, obs.created.to_s, '"created" got mangled.')
    assert(now1 <= obs.modified+1.second, '"modified" is too old.')
    assert(now2 >= obs.modified-1.second, '"modified" is too new.')

    # Now check the internal representation.  Should be UTC.
    obs = Observation.find(2)
    created = Time.utc(2006,5,12,17,20,0).in_time_zone
    assert_equal(created, obs.created, 'Time in database is wrong.')
  end

  # --------------------------------------------------------
  #  Make sure update_view_stats is working as advertised.
  # --------------------------------------------------------

  def test_update_view_stats
    User.current = @rolf
    obs      = Observation.find(2)
    image    = obs.images.first
    comment  = obs.comments.first
    interest = obs.interests.first
    location = obs.location
    name     = obs.name
    naming   = obs.namings.first
    user     = obs.user

    obs_attrs      = obs.attributes.dup
    image_attrs    = image.attributes.dup
    comment_attrs  = comment.attributes.dup
    interest_attrs = interest.attributes.dup
    location_attrs = location.attributes.dup
    name_attrs     = name.attributes.dup
    naming_attrs   = naming.attributes.dup
    user_attrs     = user.attributes.dup

    num_past_names     = Name::PastName.count
    num_past_locations = Location::PastLocation.count
    num_transactions   = Transaction.count

    for attrs, obj in [
      [ obs_attrs,      obs      ],
      [ image_attrs,    image    ],
      [ comment_attrs,  comment  ],
      [ interest_attrs, interest ],
      [ location_attrs, location ],
      [ name_attrs,     name     ],
      [ naming_attrs,   naming   ],
      [ user_attrs,     user     ],
    ]
      obj.update_view_stats
      assert_same_but_view_stats(attrs, obj.reload.attributes,
                                 "#{obj.class}#update_view_stats screwed up: ")
    end

    assert_equal(num_past_names     + 0, Name::PastName.count)
    assert_equal(num_past_locations + 0, Location::PastLocation.count)
    assert_equal(num_transactions   + 3, Transaction.count)

    t1, t2, t3 = Transaction.all
    assert_equal(:view,         t1.method)
    assert_equal(:view,         t2.method)
    assert_equal(:view,         t3.method)
    assert_equal('observation', t1.action)
    assert_equal('image',       t2.action)
    assert_equal('name',        t3.action)
    assert_equal(obs.sync_id,   t1.args[:id])
    assert_equal(image.sync_id, t2.args[:id])
    assert_equal(name.sync_id,  t3.args[:id])
  end

  # ------------------------------------------------------------------
  #  Make sure all the author/editor-related magic is working right.
  # ------------------------------------------------------------------

  def test_authors_and_editors
    for model in [Location, Name]
      case model.name
      when 'Location'
        obj = model.new(
          :display_name => 'Test Location',
          :north => 54,
          :south => 53,
          :west  => -101,
          :east  => -100,
          :high  => 100,
          :low   => 0
        )
      when 'Name'
        obj = model.new(
          :text_name        => 'Test',
          :display_name     => '**__Test sp.__**',
          :observation_name => '**__Test sp.__**',
          :search_name      => 'Test sp.',
          :rank             => :Genus
        )
      end

      msg = "#{model}: Initial conditions."
      assert_authors_and_editors(obj, [], [], msg)
      assert_contributions(0, 0, 0, 0, msg)

      # Have Rolf create minimal object.
      User.current = @rolf
      assert_save(obj)
      if model == Location
        msg = "#{model}: Rolf should be made author after minimal create."
        assert_authors_and_editors(obj, ['rolf'], [], msg)
        assert_contributions(10, 0, 0, 0, msg)
      else
        msg = "#{model}: Rolf should not be made author after minimal create."
        assert_authors_and_editors(obj, [], ['rolf'], msg)
        assert_contributions(10, 0, 0, 0, msg)
      end

      # Have Rolf make a trivial change.
      User.current = @rolf
      obj.display_name = 'Trivial Change'
      obj.save
      if model == Location
        msg = "#{model}: Rolf should still be author after trivial change."
        assert_authors_and_editors(obj, ['rolf'], [], msg)
        assert_contributions(10, 0, 0, 0, msg)
      else
        msg = "#{model}: Rolf should still be editor after trivial change."
        assert_authors_and_editors(obj, [], ['rolf'], msg)
        assert_contributions(10, 0, 0, 0, msg)
      end

      # Delete editors and author so we can test changes to old object that
      # is grandfathered in without any editors or authors.
      obj.subtract_author_contributions
      obj.authors.clear
      obj.editors.clear
      msg = "#{model}: Just deleted authors and editors."
      assert_authors_and_editors(obj, [], [], msg)
      assert_contributions(0, 0, 0, 0, msg)

      # Now have Mary make a trivial change.  Should have same result as when
      # creating above.
      User.current = @mary
      obj.display_name = 'Another Trivial Change'
      obj.save
      if model == Location
        msg = "#{model}: Mary should be made author after trivial change to authorless object."
        assert_authors_and_editors(obj, ['mary'], [], msg)
        assert_contributions(0, 10, 0, 0, msg)
      else
        msg = "#{model}: Mary should not be made author after trivial change to authorless object."
        assert_authors_and_editors(obj, [], ['mary'], msg)
        assert_contributions(0, 10, 0, 0, msg)
      end

      # Now have Dick make a non-trivial change.
      if model == Location
        obj.notes = "This is weighty stuff..."
      else
        obj.gen_desc = "This is weighty stuff..."
      end
      User.current = @dick
      obj.save
      if model == Location
        msg = "#{model}: Mary was already author, so Dick should become editor."
        assert_authors_and_editors(obj, ['mary'], ['dick'], msg)
        assert_contributions(0, 10, 5, 0, msg)
      else
        msg = "#{model}: No authors, so Dick should become author."
        assert_authors_and_editors(obj, ['dick'], ['mary'], msg)
        assert_contributions(0, 10, 100, 0, msg)
      end

      # Now have Katrina make another non-trivial change.
      if model == Location
        obj.notes = "This is even weightier stuff..."
      else
        obj.gen_desc = "This is even weightier stuff..."
      end
      User.current = @katrina
      obj.save
      if model == Location
        msg = "#{model}: Already authors, so Katrina should become editor."
        assert_authors_and_editors(obj, ['mary'], ['dick', 'katrina'], msg)
        assert_contributions(0, 10, 5, 5, msg)
      else
        msg = "#{model}: Already authors, so Katrina should become editor."
        assert_authors_and_editors(obj, ['dick'], ['mary', 'katrina'], msg)
        assert_contributions(0, 10, 100, 10, msg)
      end

      # Now force Dick and Mary both to be both authors and editors.
      # Should equalize the two cases at last.
      obj.add_author(@dick)
      obj.add_author(@mary)
      obj.add_editor(@dick)
      obj.add_editor(@mary)
      msg = "#{model}: Both Dick and Mary were just made authors supposedly."
      assert_authors_and_editors(obj, ['dick', 'mary'], ['katrina'], msg)
      if model == Location
        assert_contributions(0, 10, 10, 5, msg)
      else
        assert_contributions(0, 100, 100, 10, msg)
      end

      # And demote an author to test last feature.
      obj.remove_author(@dick)
      msg = "#{model}: Dick was just demoted supposedly."
      assert_authors_and_editors(obj, ['mary'], ['dick', 'katrina'], msg)
      if model == Location
        assert_contributions(0, 10, 5, 5, msg)
      else
        assert_contributions(0, 100, 10, 10, msg)
      end

      # Delete it to restore all contributions.
      obj.destroy
      msg = "#{model}: Just deleted the object."
      assert_contributions(0, 0, 0, 0, msg)
    end
  end

  # -------------------------------------------------------------------
  #  Test the auto-rss-log magic.  Make sure RssLog objects are being
  #  created and attached correctly, especially since we now keep a
  #  redundant rss_log_id in the owning objects.
  # -------------------------------------------------------------------

  def test_rss_log_life_cycle
    User.current = @rolf

    for model in [Location, Name, Observation, SpeciesList]
      model_name = model.name.underscore.to_sym.l.gsub(' ','%20')

      case model.name
      when 'Location'
        obj = Location.new(
          :display_name => 'Test Location',
          :north => 54,
          :south => 53,
          :west  => -101,
          :east  => -100,
          :high  => 100,
          :low   => 0
        )
      when 'Name'
        obj = Name.new(
          :text_name        => 'Test',
          :display_name     => '**__Test sp.__**',
          :observation_name => '**__Test sp.__**',
          :search_name      => 'Test sp.',
          :rank             => :Genus
        )
      when 'Observation'
        obj = Observation.new(
          :when    => Time.now,
          :where   => 'Anywhere',
          :name_id => 1
        )
      when 'SpeciesList'
        obj = SpeciesList.new(
          :when  => Time.now,
          :where => 'Anywhere',
          :title => 'Test List'
        )
      end

      num = 0
      assert_nil(obj.rss_log_id, "#{model}.rss_log shouldn't exist yet")
      assert_save(obj, "#{model}.save failed")
      if model == Location
        assert_not_nil(obj.rss_log_id, "#{model}.rss_log should exist now")
        assert_equal(obj.id, obj.rss_log.send("#{model.name.underscore}_id"),
                     "#{model}.rss_log ids don't match")
        assert_equal((num+=1), obj.rss_log.notes.split("\n").length,
                     "#{model}.rss_log should only have creation line:\n" +
                     "<#{obj.rss_log.notes}>")
        assert_match(/log_object_created.*#{model_name}/, obj.rss_log.notes,
                     "#{model}.rss_log should have creation line:\n" +
                     "<#{obj.rss_log.notes}>")
      else
        assert_nil(obj.rss_log_id, "#{model}.rss_log shouldn't exist yet")
      end

      time = obj.rss_log.modified if obj.rss_log
      obj.log(:test_message, :arg => 'val')
      if model != Location
        assert_not_nil(obj.rss_log_id, "#{model}.rss_log should exist now")
        assert_equal(obj.id, obj.rss_log.send("#{model.name.underscore}_id"),
                     "#{model}.rss_log ids don't match")
      end
      assert_equal((num+=1), obj.rss_log.notes.split("\n").length,
                   "#{model}.rss_log should have create and test lines:\n" +
                   "<#{obj.rss_log.notes}>")
      assert_match(/test_message.*arg.*val/, obj.rss_log.notes,
                   "#{model}.rss_log should have test line:\n" +
                   "<#{obj.rss_log.notes}>")
      assert_not_equal(time, obj.rss_log.modified,
                       "#{model}.rss_log wasn't touched")

      time = obj.rss_log.modified
      case model
      when Location
        obj.display_name = 'New Location'
      when Name
        obj.author = 'New Author'
      when Observation
        obj.notes = 'New Notes'
      when SpeciesList
        obj.title = 'New Title'
      end
      obj.save
      if model == Location
        assert_equal((num+=1), obj.rss_log.notes.split("\n").length,
                     "#{model}.rss_log should have create, test, update lines:\n" +
                     "<#{obj.rss_log.notes}>")
        assert_match(/log_object_updated.*#{model_name}/, obj.rss_log.notes,
                     "#{model}.rss_log should have update line:\n" +
                     "<#{obj.rss_log.notes}>")
        assert_not_equal(time, obj.rss_log.modified,
                         "#{model}.rss_log wasn't touched")
      end

      time = obj.rss_log.modified
      obj.destroy
      assert_equal((num+=2), obj.rss_log.notes.split("\n").length,
                   "#{model}.rss_log should have create, test, update, destroy, orphan lines:\n" +
                   "<#{obj.rss_log.notes}>")
      assert_match(/log_object_destroyed.*#{model_name}/, obj.rss_log.notes,
                   "#{model}.rss_log should have destroy line:\n" +
                   "<#{obj.rss_log.notes}>")
      assert_equal(time, obj.rss_log.modified,
                   "#{model}.rss_log shouldn't have been touched")
    end
  end
end
