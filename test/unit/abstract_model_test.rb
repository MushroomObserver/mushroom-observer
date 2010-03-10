require File.dirname(__FILE__) + '/../boot'

class AbstractModelTest < UnitTestCase

  # Make sure update_view_stats updated stuff correctly (and did nothing else).
  def assert_same_but_view_stats(old_attrs, new_attrs, msg='')
    for key in (old_attrs.keys + new_attrs.keys).map(&:to_s).uniq.sort
      old_val = old_attrs[key]
      new_val = new_attrs[key]
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
    loc_desc = obs.location.description
    name     = obs.name
    name_desc= obs.name.description
    naming   = obs.namings.first
    user     = obs.user

    obs_attrs      = obs.attributes.dup
    image_attrs    = image.attributes.dup
    comment_attrs  = comment.attributes.dup
    interest_attrs = interest.attributes.dup
    location_attrs = location.attributes.dup
    assert_nil(loc_desc)
    name_attrs     = name.attributes.dup
    assert_nil(name_desc)
    naming_attrs   = naming.attributes.dup
    user_attrs     = user.attributes.dup

    num_past_names     = Name::Version.count
    num_past_name_descs= NameDescription::Version.count
    num_past_locations = Location::Version.count
    num_past_loc_descs = LocationDescription::Version.count
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

    assert_equal(num_past_names     + 0, Name::Version.count)
    assert_equal(num_past_name_descs+ 0, NameDescription::Version.count)
    assert_equal(num_past_locations + 0, Location::Version.count)
    assert_equal(num_past_loc_descs + 0, LocationDescription::Version.count)
    assert_equal(num_transactions   + 0, Transaction.count)
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
