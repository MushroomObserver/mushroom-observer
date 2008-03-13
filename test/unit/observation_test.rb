require File.dirname(__FILE__) + '/../test_helper'

class ObservationTest < Test::Unit::TestCase
  fixtures :observations
  fixtures :users
  fixtures :names
  fixtures :namings
  fixtures :images

  def setup
    @cc_obs = Observation.new
    @cc_obs.user = @mary
    @cc_obs.where = "Glendale, California"
    @cc_obs.notes = "New"
    @cc_nam = Naming.new
    @cc_nam.user = @mary
    @cc_nam.name = @fungi
    @cc_nam.observation = @cc_obs
  end
  
  # Add an observation to the database
  def test_create
    assert_kind_of Observation, observations(:minimal_unknown)
    assert_kind_of Observation, @cc_obs
    assert_kind_of Naming, namings(:minimal_unknown_naming)
    assert_kind_of Naming, @cc_nam
    assert @cc_obs.save, @detailed_unknown.errors.full_messages.join("; ")
    assert @cc_nam.save, @detailed_unknown_naming.errors.full_messages.join("; ")
  end

  def test_update
    @cc_nam.save
    assert_equal @fungi, @cc_nam.name
    @cc_nam.name = @coprinus_comatus
    assert @cc_nam.save, @cc_nam.errors.full_messages.join("; ")
    @cc_nam.reload
    assert_equal @coprinus_comatus.search_name, @cc_nam.text_name
  end

  # Test setting a name using a string
  
  def test_validate
    @cc_obs.user = nil
    @cc_obs.where = nil
    assert !@cc_obs.save
    assert_equal 2, @cc_obs.errors.count
    assert_equal "can't be blank", @cc_obs.errors.on(:user)
    assert_equal "can't be blank", @cc_obs.errors.on(:where)
  end

  def test_destroy
    @cc_obs.save
    @cc_nam.save
    @cc_obs.destroy
    assert_raise(ActiveRecord::RecordNotFound) { Observation.find(@cc_obs.id) }
    assert_raise(ActiveRecord::RecordNotFound) { Naming.find(@cc_nam.id) }
  end

  def test_all_observations_order
    obs = Observation.find(:all, :order => "id")
    assert_equal @coprinus_comatus_obs.id, obs[2].id
    assert_equal @detailed_unknown.id, obs[1].id
  end
  
  def test_remove_image_by_id_twice
    @minimal_unknown.images = [
      @commercial_inquiry_image,
      @disconnected_coprinus_comatus_image,
      @connected_coprinus_comatus_image
    ]
    @minimal_unknown.thumb_image = @commercial_inquiry_image
    @minimal_unknown.remove_image_by_id(@commercial_inquiry_image.id)
    assert_equal(@minimal_unknown.thumb_image, @disconnected_coprinus_comatus_image)
    @minimal_unknown.remove_image_by_id(@disconnected_coprinus_comatus_image.id)
    assert_equal(@minimal_unknown.thumb_image, @connected_coprinus_comatus_image)
  end

  def test_name_been_proposed
    assert(@coprinus_comatus_obs.name_been_proposed?(@coprinus_comatus))
    assert(@coprinus_comatus_obs.name_been_proposed?(@agaricus_campestris))
    assert(!@coprinus_comatus_obs.name_been_proposed?(@conocybe_filaris))
  end
end
