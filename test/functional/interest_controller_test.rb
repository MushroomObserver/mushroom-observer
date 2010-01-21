require File.dirname(__FILE__) + '/../test_helper'
require 'interest_controller'

class InterestControllerTest < Test::Unit::TestCase
  fixtures :interests
  fixtures :observations
  fixtures :names
  fixtures :users

  def setup
    @controller = InterestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

################################################################################

  # Test list feature from left-hand column.
  def test_list_interests
    @request.session[:user_id] = 1
    Interest.create(:object => @minimal_unknown, :user => @rolf, :state => true)
    Interest.create(:object => @agaricus_campestris, :user => @rolf, :state => true)
    get_with_dump(:list_interests)
    assert_response(:list_interests)
  end

  # Test callback.
  def test_set_interest
    # Fail: Try to change another user's interest.
    @request.session[:user_id] = @rolf.id
    get(:set_interest, :type => 'Observation', :id => 1, :user => @mary.id)
    assert_equal(2, flash[:notice_level])
    flash[:notice_level] = nil

    # Fail: Try to change interest in non-existing object.
    @request.session[:user_id] = @rolf.id
    get(:set_interest, :type => 'Observation', :id => 100, :state => 1)
    assert_equal(2, flash[:notice_level])
    flash[:notice_level] = nil

    # Fail: Try to change interest in non-existing object.
    @request.session[:user_id] = @rolf.id
    get(:set_interest, :type => 'Bogus', :id => 1, :state => 1)
    assert_equal(2, flash[:notice_level])
    flash[:notice_level] = nil

    # Succeed: Turn interest on in @minimal_unknown.
    @request.session[:user_id] = @rolf.id
    get(:set_interest, :type => 'Observation', :id => @minimal_unknown.id, :state => 1)
    assert_equal(nil, flash[:notice_level])
    flash[:notice_level] = nil
    
    # Make sure rolf now has one Interest: interested in @minimal_unknown.
    rolfs_interests = Interest.find_all_by_user_id(@rolf.id)
    assert_equal(1, rolfs_interests.length)
    assert_equal(@minimal_unknown, rolfs_interests.first.object)
    assert_equal(true, rolfs_interests.first.state)

    # Succeed: Turn same interest off.
    @request.session[:user_id] = @rolf.id
    get(:set_interest, :type => 'Observation', :id => @minimal_unknown.id, :state => -1)
    assert_equal(nil, flash[:notice_level])
    flash[:notice_level] = nil

    # Make sure rolf now has one Interest: NOT interested in @minimal_unknown.
    rolfs_interests = Interest.find_all_by_user_id(@rolf.id)
    assert_equal(1, rolfs_interests.length)
    assert_equal(@minimal_unknown, rolfs_interests.first.object)
    assert_equal(false, rolfs_interests.first.state)

    # Succeed: Turn another interest off from no interest.
    @request.session[:user_id] = @rolf.id
    get(:set_interest, :type => 'Name', :id => @peltigera.id, :state => -1)
    assert_equal(nil, flash[:notice_level])
    flash[:notice_level] = nil

    # Make sure rolf now has two Interests.
    rolfs_interests = Interest.find_all_by_user_id(@rolf.id)
    assert_equal(2, rolfs_interests.length)
    assert_equal(@minimal_unknown, rolfs_interests.first.object)
    assert_equal(false, rolfs_interests.first.state)
    assert_equal(@peltigera, rolfs_interests.last.object)
    assert_equal(false, rolfs_interests.last.state)

    # Succeed: Delete interest in existing object that rolf hasn't expressed interest in yet.
    @request.session[:user_id] = @rolf.id
    get(:set_interest, :type => 'Observation', :id => @detailed_unknown.id, :state => 0)
    assert_equal(nil, flash[:notice_level])
    flash[:notice_level] = nil
    assert_equal(2, Interest.find_all_by_user_id(@rolf.id).length)

    # Succeed: Delete first interest now.
    @request.session[:user_id] = @rolf.id
    get(:set_interest, :type => 'Observation', :id => @minimal_unknown.id, :state => 0)
    assert_equal(nil, flash[:notice_level])
    flash[:notice_level] = nil

    # Make sure rolf now has one Interest: NOT interested in @peltigera.
    rolfs_interests = Interest.find_all_by_user_id(@rolf.id)
    assert_equal(1, rolfs_interests.length)
    assert_equal(@peltigera, rolfs_interests.last.object)
    assert_equal(false, rolfs_interests.last.state)

    # Succeed: Delete last interest.
    @request.session[:user_id] = @rolf.id
    get(:set_interest, :type => 'Name', :id => @peltigera.id, :state => 0)
    assert_equal(nil, flash[:notice_level])
    flash[:notice_level] = nil
    assert_equal(0, Interest.find_all_by_user_id(@rolf.id).length)
  end
end
