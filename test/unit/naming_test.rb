require File.dirname(__FILE__) + '/../boot'

class NamingTest < Test::Unit::TestCase
  fixtures :observations
  fixtures :users
  fixtures :names
  fixtures :namings
  fixtures :votes

  # Propose a naming for an observation.
  def test_create
    assert_kind_of Observation, @coprinus_comatus_obs
    now = Time.now
    naming = Naming.new(
        :created        => now,
        :modified       => now,
        :observation_id => @coprinus_comatus_obs.id,
        :name_id        => @agaricus_campestris.id,
        :user_id        => @mary.id
    )
    assert naming.save, naming.errors.full_messages.join("; ")
  end

  # Change an existing one.
  def test_update
    assert_kind_of Observation, @coprinus_comatus_obs
    assert_kind_of Naming, @coprinus_comatus_naming
    assert_kind_of Name, @coprinus_comatus
    assert_kind_of Name, @agaricus_campestris
    assert_equal @coprinus_comatus, @coprinus_comatus_naming.name
    assert_equal @coprinus_comatus, @coprinus_comatus_obs.name
    @coprinus_comatus_naming.modified = Time.now
    @coprinus_comatus_naming.name = @agaricus_campestris
    assert @coprinus_comatus_naming.save
    assert @coprinus_comatus_naming.errors.full_messages.join("; ")
    @coprinus_comatus_naming.reload
    @coprinus_comatus_obs.reload
    @coprinus_comatus_obs.calc_consensus
    assert_equal @agaricus_campestris, @coprinus_comatus_naming.name
    assert_equal @agaricus_campestris, @coprinus_comatus_obs.name
  end

  # Make sure it fails if we screw up.
  def test_validate
    naming = Naming.new
    assert !naming.save
    assert_equal 3, naming.errors.count
    assert_equal :validate_naming_name_missing.t, naming.errors.on(:name)
    assert_equal :validate_naming_observation_missing.t, naming.errors.on(:observation)
    assert_equal :validate_naming_user_missing.t, naming.errors.on(:user)
  end

  # Destroy one.
  def test_destroy
    assert_equal @coprinus_comatus, @coprinus_comatus_obs.name
    id = @coprinus_comatus_naming.id
    User.current = @rolf
    @coprinus_comatus_naming.destroy
    @coprinus_comatus_obs.reload
    @coprinus_comatus_obs.calc_consensus
    assert_raise(ActiveRecord::RecordNotFound) { Naming.find(id) }
    assert_equal @agaricus_campestris, @coprinus_comatus_obs.name
  end
end
