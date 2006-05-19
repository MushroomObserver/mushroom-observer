require File.dirname(__FILE__) + '/../test_helper'

class ObservationTest < Test::Unit::TestCase
  fixtures :observations

  def setup
    @mu = Observation.find(1)
    @du = Observation.find(2)
  end

  # Replace this with your real tests.
  def test_create
    assert_kind_of Observation, @mu
    assert_equal @minimal_unknown.id, @mu.id
    assert_equal @minimal_unknown.who, @mu.who
    assert_equal @minimal_unknown.where, @mu.where

    assert_kind_of Observation, @du
    assert_equal @detailed_unknown.id, @du.id
    assert_equal @detailed_unknown.created, @du.created
    assert_equal @detailed_unknown.modified, @du.modified
    assert_equal @detailed_unknown.when, @du.when
    assert_equal @detailed_unknown.who, @du.who
    assert_equal @detailed_unknown.where, @du.where
    assert_equal @detailed_unknown.what, @du.what
    assert_equal @detailed_unknown.specimen, @du.specimen
    assert_equal @detailed_unknown.notes, @du.notes
  end

  def test_update
    assert_equal 'Unknown', @du.what
    @du.what = 'Agaricus augustus'
    assert @du.save, @du.errors.full_messages.join("; ")
    @du.reload
    assert_equal 'Agaricus augustus', @du.what
  end

  def test_validate
    assert_equal @minimal_unknown.who, @mu.who
    @mu.who = nil
    @mu.where = nil
    assert !@mu.save
    assert_equal 3, @mu.errors.count
    assert_equal "can't be blank", @mu.errors.on(:who)
    assert_equal "can't be blank", @mu.errors.on(:where)
    assert_equal "at least one of Notes, What or Image must be provided",
                 @mu.errors.on(:notes)
  end

  def test_destroy
    @mu.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Observation.find(@mu.id) }
    @du.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Observation.find(@du.id) }
  end

  def test_all_observations_order
    obs = Observation.all_observations
    assert_equal @older_than_dirt.id, obs[-1].id
    assert_equal @dirt.id, obs[-2].id
  end
end
