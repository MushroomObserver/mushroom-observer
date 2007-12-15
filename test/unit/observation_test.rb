require File.dirname(__FILE__) + '/../test_helper'

class ObservationTest < Test::Unit::TestCase
  fixtures :observations
  fixtures :users
  fixtures :names

  def setup
    @cc_obs = Observation.new
    @cc_obs.user = @mary
    @cc_obs.where = "Glendale, California"
    @cc_obs.name = @fungi
    @cc_obs.notes = "New"
  end
  
  # Add an observation to the database
  def test_create
    assert_kind_of Observation, observations(:minimal_unknown)
    assert_kind_of Observation, @cc_obs
    assert @cc_obs.save, @detailed_unknown.errors.full_messages.join("; ")
  end

  def test_update
    @cc_obs.save
    assert_equal @fungi, @cc_obs.name
    @cc_obs.name = @coprinus_comatus
    assert @cc_obs.save, @cc_obs.errors.full_messages.join("; ")
    @cc_obs.reload
    assert_equal @coprinus_comatus.search_name, @cc_obs.what
  end

  # Test setting a name using a string
  
  def test_validate
    @cc_obs.user = nil
    @cc_obs.where = nil
    assert !@cc_obs.save
    assert_equal 1, @cc_obs.errors.count
    assert_equal "can't be blank", @cc_obs.errors.on(:user)
  end

  def test_destroy
    @cc_obs.save
    @cc_obs.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Observation.find(@cc_obs.id) }
  end

  def test_all_observations_order
    obs = Observation.find(:all, :order => "id")
    assert_equal @coprinus_comatus_obs.id, obs[2].id
    assert_equal @detailed_unknown.id, obs[1].id
  end
end
