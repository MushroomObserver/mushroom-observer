require File.dirname(__FILE__) + '/../boot'

class ActiveRecordTest < Test::Unit::TestCase
  fixtures :users

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

################################################################################

  def test_time_zone
    local_fixtures :observations

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

  def test_update_view_stats
    local_fixtures :comments
    local_fixtures :images
    local_fixtures :images_observations
    local_fixtures :interests
    local_fixtures :locations
    local_fixtures :names
    local_fixtures :namings
    local_fixtures :observations

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

    assert_equal(0, Name::PastName.all.length)
    assert_equal(0, Location::PastLocation.all.length)
    assert_equal(0, Transaction.all.length)

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

    assert_equal(0, Name::PastName.all.length)
    assert_equal(0, Location::PastLocation.all.length)
    assert_equal(3, Transaction.all.length)

    t1, t2, t3 = Transaction.all
    assert_equal('view',        t1.method)
    assert_equal('view',        t2.method)
    assert_equal('view',        t3.method)
    assert_equal('observation', t1.action)
    assert_equal('image',       t2.action)
    assert_equal('name',        t3.action)
    assert_equal(obs.sync_id,   t1.args[:id])
    assert_equal(image.sync_id, t2.args[:id])
    assert_equal(name.sync_id,  t3.args[:id])
  end
end
