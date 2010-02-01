require File.dirname(__FILE__) + '/../boot'

class NamingTest < Test::Unit::TestCase

  # Propose a naming for an observation.
  def test_create
    assert_kind_of Observation, observations(:coprinus_comatus_obs)
    now = Time.now
    naming = Naming.new(
        :created        => now,
        :modified       => now,
        :observation_id => observations(:coprinus_comatus_obs).id,
        :name_id        => names(:agaricus_campestris).id,
        :user_id        => @mary.id
    )
    assert naming.save, naming.errors.full_messages.join("; ")
  end

  # Change an existing one.
  def test_update
    assert_kind_of Observation, observations(:coprinus_comatus_obs)
    assert_kind_of Naming, namings(:coprinus_comatus_naming)
    assert_kind_of Name, names(:coprinus_comatus)
    assert_kind_of Name, names(:agaricus_campestris)
    assert_equal names(:coprinus_comatus), namings(:coprinus_comatus_naming).name
    assert_equal names(:coprinus_comatus), observations(:coprinus_comatus_obs).name
    namings(:coprinus_comatus_naming).modified = Time.now
    namings(:coprinus_comatus_naming).name = names(:agaricus_campestris)
    assert namings(:coprinus_comatus_naming).save
    assert namings(:coprinus_comatus_naming).errors.full_messages.join("; ")
    namings(:coprinus_comatus_naming).reload
    observations(:coprinus_comatus_obs).reload
    observations(:coprinus_comatus_obs).calc_consensus
    assert_equal names(:agaricus_campestris), namings(:coprinus_comatus_naming).name
    assert_equal names(:agaricus_campestris), observations(:coprinus_comatus_obs).name
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
    assert_equal names(:coprinus_comatus), observations(:coprinus_comatus_obs).name
    id = namings(:coprinus_comatus_naming).id
    User.current = @rolf
    namings(:coprinus_comatus_naming).destroy
    observations(:coprinus_comatus_obs).reload
    observations(:coprinus_comatus_obs).calc_consensus
    assert_raise(ActiveRecord::RecordNotFound) { Naming.find(id) }
    assert_equal names(:agaricus_campestris), observations(:coprinus_comatus_obs).name
  end
end
