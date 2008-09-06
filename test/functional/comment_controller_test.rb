require File.dirname(__FILE__) + '/../test_helper'
require 'comment_controller'

class CommentControllerTest < Test::Unit::TestCase
  fixtures :comments
  fixtures :observations
  fixtures :namings
  fixtures :names
  fixtures :locations
  fixtures :users

  def setup
    @controller = CommentController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_list_comments
    get_with_dump :list_comments
    assert_response :success
    assert_template 'list_comments'
  end

  def test_show_comment
    get_with_dump :show_comment, :id => 1
    assert_response :success
    assert_template 'show_comment'
  end

  def test_show_comments_for_user
    get_with_dump :show_comments_for_user, :id => 1
    assert_response :success
    assert_template("list_comments")
  end

  def test_show_comments_by_user
    get_with_dump :show_comments_by_user, :id => @rolf.id
    assert_response :success
    assert_template("list_comments")
  end

  def test_add_comment
    requires_login :add_comment, {:id => 1}
    assert_form_action :action => 'add_comment'
  end

  def test_edit_comment
    comment = @minimal_comment
    params = { "id" => comment.id.to_s }
    assert("rolf" == comment.user.login)
    requires_user(:edit_comment, :show_comment, params)
    assert_form_action :action => 'edit_comment'
  end

  def test_destroy_comment
    comment = @minimal_comment
    obs = comment.observation
    assert(obs.comments.member?(comment))
    params = {"id"=>comment.id.to_s}
    assert("rolf" == comment.user.login)
    requires_user(:destroy_comment, :show_comment, params, false)
    assert_equal(9, @rolf.reload.contribution)
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = Observation.find(obs.id) # Need to reload observation to pick up changes
    assert(!obs.comments.member?(comment))
  end

  def test_save_comment
    obs = @minimal_unknown
    comment_count = obs.comments.size
    params = {
      :id => obs.id,
      :comment => {
        :summary => "A Summary",
        :comment => "Some text."
      }
    }
    post_requires_login :add_comment, params, false
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    assert_equal(11, @rolf.reload.contribution)
    obs = Observation.find(obs.id)
    assert(obs.comments.size == (comment_count + 1))
    comment = Comment.find(:all).last
    assert(comment.summary == "A Summary")
    assert(comment.comment == "Some text.")
  end

  # Reproduces problem with a spontaneous logout between
  # add_comment and save_comment
  def test_save_comment_indirect_params
    obs = @minimal_unknown
    comment_count = obs.comments.size
    comment_params = {
      :id => obs.id,
      :comment => {
        "summary" => "Garble",
        "comment" => "Blarble."
      }
    }
    post(:add_comment, comment_params)
    assert_redirected_to(:controller => "account", :action => "login")
    assert_equal(flash[:params][:comment], comment_params[:comment])
    # Have to do login explicitly to manage the session object correctly.
    # Will have to test hidden inputs, etc. in account controller tester.
    user = User.authenticate('rolf', 'testpassword')
    assert(user)
    session[:user_id] = user.id
    post_with_dump(:add_comment, {})
    assert_redirected_to(:controller => "observer", :action => "show_observation")
    obs = Observation.find(obs.id)
    assert_equal(obs.comments.size, comment_count + 1)
    assert_equal(obs.comments.last.summary, "Garble")
    assert_equal(obs.comments.last.comment, "Blarble.")
  end

  def test_update_comment
    comment = @minimal_comment
    params = {
      :id => comment.id,
      :comment => {
        :summary => "New Summary",
        :comment => "New text."
      }
    }
    assert("rolf" == comment.user.login)
    post_requires_user(:edit_comment, :show_comment, params, false)
    assert_equal(10, @rolf.reload.contribution)
    comment = Comment.find(comment.id)
    assert(comment.summary == "New Summary")
    assert(comment.comment == "New text.")
  end
end
