# Copyright (c) 2008 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

################################################################################
#
#  Views:
#    list_comments              List latest comments.
#    show_comments_for_user     Show a comments *for* a user.
#    show_comments_by_user      Show a comments *by* a user.
#    show_comment               Show a single comment.
#    add_comment                Create a comment.
#    edit_comment               Edit a comment.
#    destroy_comment            Destroy comment.
#
################################################################################

class CommentController < ApplicationController
  before_filter :login_required, :except => [
    :list_comments,
    :show_comments_for_user,
    :show_comments_by_user,
    :show_comment
  ]

  # Show list of latest comments.
  # Linked from: left-hand panel
  # Inputs: params[:page], session['user']
  # Outputs: @user, @comments, @comment_pages
  def list_comments
    store_location
    session_setup
    @title = "Comments"
    @comment_pages, @comments = paginate(:comments,
                                     :order => "'created' desc",
                                     :per_page => 10)
  end

  # Shows comments for a given user, most recent first.
  # Linked from: left panel
  # View: list_comments
  # Inputs: params[:id] (user), session['user']
  # Outputs: @user, @comments, @comment_pages
  def show_comments_for_user
    session_setup
    store_location
    @user = User.find(params[:id])
    @title = "Comments for %s" % @user.legal_name
    @comment_pages, @comments = paginate(:comments, :include => "observation",
                                         :order => "comments.created desc",
                                         :conditions => "observations.user_id = %s" % @user.id,
                                         :per_page => 10)
    render :action => 'list_comments'
  end

  # Shows comments for a given user, most recent first.
  # Linked from: left panel
  # View: list_comments
  # Inputs: params[:id] (user), session['user']
  # Outputs: @user, @comments, @comment_pages
  def show_comments_by_user
    session_setup
    store_location
    @user = User.find(params[:id])
    @title = "Comments by %s" % @user.legal_name
    @comment_pages, @comments = paginate(:comments, :order => "created desc",
                                         :conditions => "user_id = %s" % @user.id,
                                         :per_page => 10)
    render :action => 'list_comments'
  end

  # Display comment by itself.
  # Linked from: show_observation, list_comments
  # Inputs: params[:id] (comment), session['user']
  # Outputs: @comment, @user
  def show_comment
    store_location
    @user = session['user']
    @comment = Comment.find(params[:id])
  end

  # Form to create comment for an observation.
  # Linked from: show_observation
  # Inputs:
  #   params[:id] (observation)
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  #   session['user']
  # Success:
  #   Redirects to show_observation.
  # Failure:
  #   Renders add_comment again.
  #   Outputs: @comment, @observation, @user
  def add_comment
    if verify_user()
      pass_seq_params()
      @user = session['user']
      @observation = Observation.find(params[:id])
      if request.method == :get
        @comment = Comment.new
      else
        @comment = Comment.new(params[:comment])
        @comment.created = Time.now
        @comment.user = @user
        @comment.observation = @observation
        if @comment.save
          @observation.log("Comment added by #{@user.login}: #{@comment.summary}", true)
          flash_notice "Comment was successfully added."
          redirect_to :controller => 'observer', :action => 'show_observation', :id => @observation, :params => calc_search_params()
        else
          flash_object_errors(@comment)
        end
      end
    end
  end

  # Form to edit a comment for an observation.
  # Linked from: show_comment, show_observation
  # Inputs:
  #   params[:id]
  #   params[:comment][:summary]
  #   params[:comment][:comment]
  #   session['user']
  # Success:
  #   Redirects to show_comment.
  # Failure:
  #   Renders edit_comment again.
  #   Outputs: @comment, @observation, @user
  def edit_comment
    @user = session['user']
    @comment = Comment.find(params[:id])
    @observation = @comment.observation if @comment
    if !check_user_id(@comment.user_id)
      render :action => 'show_comment'
    elsif request.method == :post
      if !@comment.update_attributes(params[:comment]) || !@comment.save
        flash_object_errors(@comment)
      else
        @comment.observation.log("Comment updated by #{@user.login}: #{@comment.summary}", false)
        flash_notice "Comment was successfully updated."
        redirect_to :action => 'show_comment', :id => @comment
      end
    end
  end

  # Callback to destroy a comment.
  # Linked from: show_comment, show_observation
  # Redirects to show_observation.
  # Inputs: params[:id], session['user']
  # Outputs: none
  def destroy_comment
    @user = session['user']
    @comment = Comment.find(params[:id])
    if !check_user_id(@comment.user_id)
      render :action => 'show_comment'
    else
      obs = @comment.observation
      sum = @comment.summary
      if @comment.destroy
        obs.log("Comment destroyed by #{@user.login}: #{sum}", false)
        flash_notice "Comment destroyed."
      else
        flash_error "Failed to destroy comment."
      end
      redirect_to :controller => 'observer', :action => 'show_observation', :id => obs.id
    end
  end
end
